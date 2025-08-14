//
//  ActivityMonitor.swift
//  WorkLifeBalance
//

import Foundation
import CoreGraphics
import AppKit
@preconcurrency import Combine
import OSLog

// MARK: - Activity Events
enum ActivityEvent: Sendable {
    case userActivity(Date)
    case idleStateChanged(Bool)
    case applicationChanged(String?)
    case mouseActivity(CGPoint)
}

// MARK: - Activity Monitor Errors
enum ActivityMonitorError: Error, LocalizedError {
    case monitorSetupFailed(String)
    case permissionDenied(String)
    case systemEventAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .monitorSetupFailed(let message):
            return "Activity monitor setup failed: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .systemEventAccessDenied:
            return "System event access denied. Please grant accessibility permissions."
        }
    }
}

// MARK: - Application Info
struct ApplicationInfo: Sendable {
    let name: String?
    let bundleIdentifier: String?
    let isActive: Bool
    let timestamp: Date
}

/// Modern activity monitor using Swift concurrency and Combine
@MainActor
final class ActivityMonitor: ObservableObject, Sendable {
    // MARK: - Publishers
    @Published private(set) var lastActivityTime: Date = Date()
    @Published private(set) var isIdle: Bool = false
    @Published private(set) var currentApplication: ApplicationInfo?
    @Published private(set) var mousePosition: CGPoint = .zero
    
    // MARK: - Combine Publishers
    nonisolated private let activitySubject = PassthroughSubject<ActivityEvent, Never>()
    private let idleThreshold: TimeInterval = 300 // 5 minutes
    private let logger = Logger(subsystem: "WorkLifeBalance", category: "ActivityMonitor")
    
    // MARK: - Event Monitoring
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var workspaceObserver: NSObjectProtocol?
    private var idleCheckTask: Task<Void, Never>?
    
    // MARK: - Concurrency
    private let monitoringQueue = DispatchQueue(label: "activityMonitor", qos: .utility)
    
    nonisolated init() {
        Task { @MainActor in
            await setupMonitoring()
        }
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public API
    
    /// Publisher for activity events
    nonisolated var activityPublisher: AnyPublisher<ActivityEvent, Never> {
        activitySubject.eraseToAnyPublisher()
    }
    
    /// Get current idle time
    var currentIdleTime: TimeInterval {
        Date().timeIntervalSince(lastActivityTime)
    }
    
    /// Check if user is currently idle
    var userIsIdle: Bool {
        currentIdleTime > idleThreshold
    }
    
    /// Start monitoring user activity
    func startMonitoring() async throws {
        logger.info("Starting activity monitoring")
        
        guard await checkAccessibilityPermissions() else {
            throw ActivityMonitorError.permissionDenied("Accessibility permissions required")
        }
        
        try await setupEventMonitors()
        setupWorkspaceMonitoring()
        startIdleChecking()
        
        logger.info("Activity monitoring started successfully")
    }
    
    /// Stop monitoring user activity
    func stopMonitoring() {
        logger.info("Stopping activity monitoring")
        cleanup()
    }
    
    /// Get current active application asynchronously
    func getCurrentApplication() async -> ApplicationInfo? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let app = NSWorkspace.shared.frontmostApplication
                let info = ApplicationInfo(
                    name: app?.localizedName,
                    bundleIdentifier: app?.bundleIdentifier,
                    isActive: true,
                    timestamp: Date()
                )
                continuation.resume(returning: info)
            }
        }
    }
    
    /// Stream of application changes
    nonisolated func applicationChanges() -> AsyncStream<ApplicationInfo> {
        AsyncStream { continuation in
            let cancellable = activityPublisher
                .compactMap { event in
                    if case .applicationChanged(let appName) = event {
                        return ApplicationInfo(
                            name: appName,
                            bundleIdentifier: nil,
                            isActive: true,
                            timestamp: Date()
                        )
                    }
                    return nil
                }
                .sink { appInfo in
                    continuation.yield(appInfo)
                }
            
            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }
    }
    
    /// Stream of idle state changes
    nonisolated func idleStateChanges() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let cancellable = activityPublisher
                .compactMap { event in
                    if case .idleStateChanged(let isIdle) = event {
                        return isIdle
                    }
                    return nil
                }
                .sink { isIdle in
                    continuation.yield(isIdle)
                }
            
            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupMonitoring() async {
        do {
            try await startMonitoring()
        } catch {
            logger.error("Failed to setup monitoring: \(error.localizedDescription)")
        }
    }
    
    private func checkAccessibilityPermissions() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let trusted = AXIsProcessTrusted()
                continuation.resume(returning: trusted)
            }
        }
    }
    
    private func setupEventMonitors() async throws {
        // Remove existing monitors
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Setup global event monitor
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            Task { @MainActor in
                await self?.handleUserActivity(event)
            }
        }
        
        // Setup local event monitor  
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            Task { @MainActor in
                await self?.handleUserActivity(event)
            }
            return event
        }
        
        if globalMonitor == nil || localMonitor == nil {
            throw ActivityMonitorError.monitorSetupFailed("Failed to create event monitors")
        }
    }
    
    private func setupWorkspaceMonitoring() {
        // Remove existing observer
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        
        // Monitor application changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleApplicationChange()
            }
        }
    }
    
    private func handleUserActivity(_ event: NSEvent) async {
        let currentTime = Date()
        let wasIdle = isIdle
        
        lastActivityTime = currentTime
        mousePosition = NSEvent.mouseLocation
        
        // Update idle state
        if wasIdle {
            isIdle = false
            activitySubject.send(.idleStateChanged(false))
            logger.debug("User returned from idle state")
        }
        
        // Send activity event
        activitySubject.send(.userActivity(currentTime))
        activitySubject.send(.mouseActivity(mousePosition))
    }
    
    private func handleApplicationChange() async {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return
        }
        
        let appInfo = ApplicationInfo(
            name: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            isActive: true,
            timestamp: Date()
        )
        
        currentApplication = appInfo
        activitySubject.send(.applicationChanged(app.localizedName))
        
        logger.debug("Application changed to: \(app.localizedName ?? "Unknown")")
    }
    
    private func startIdleChecking() {
        // Cancel existing task
        idleCheckTask?.cancel()
        
        // Start new idle checking task
        idleCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10)) // Check every 10 seconds
                
                await MainActor.run {
                    let wasIdle = isIdle
                    let currentlyIdle = currentIdleTime > idleThreshold
                    
                    if wasIdle != currentlyIdle {
                        isIdle = currentlyIdle
                        activitySubject.send(.idleStateChanged(currentlyIdle))
                        
                        if currentlyIdle {
                            logger.debug("User became idle after \(self.currentIdleTime) seconds")
                        }
                    }
                }
            }
        }
    }
    
    private nonisolated func cleanup() {
        Task { @MainActor in
            // Cancel idle checking
            idleCheckTask?.cancel()
            
            // Remove event monitors
            if let monitor = globalMonitor {
                NSEvent.removeMonitor(monitor)
                globalMonitor = nil
            }
            
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
            
            // Remove workspace observer
            if let observer = workspaceObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
                workspaceObserver = nil
            }
            
            logger.info("Activity monitoring cleaned up")
        }
    }
}