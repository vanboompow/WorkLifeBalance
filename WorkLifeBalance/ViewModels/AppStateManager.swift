//
//  AppStateManager.swift
//  WorkLifeBalance
//

import Foundation
import SwiftUI
import Combine
import AppKit
import OSLog
import Observation

// MARK: - Work State
enum WorkState: String, Codable, CaseIterable, Sendable {
    case working = "working"
    case resting = "resting"
    case idle = "idle"
    
    var description: String {
        switch self {
        case .working: return "Working"
        case .resting: return "Resting"
        case .idle: return "Idle"
        }
    }
    
    var color: Color {
        switch self {
        case .working: return .green
        case .resting: return .blue
        case .idle: return .gray
        }
    }
    
    var systemImageName: String {
        switch self {
        case .working: return "laptop.and.pencil"
        case .resting: return "cup.and.saucer"
        case .idle: return "moon.zzz"
        }
    }
}

// MARK: - App State Manager Errors
enum AppStateError: Error, LocalizedError {
    case databaseError(String)
    case activityMonitorError(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "Database error: \(message)"
        case .activityMonitorError(let message):
            return "Activity monitor error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

// MARK: - Modern App State Manager
@MainActor
@Observable
final class AppStateManager: ObservableObject, Sendable {
    static let shared = AppStateManager()
    
    // MARK: - Observable State
    var currentState: WorkState = .idle
    var workTime: TimeInterval = 0
    var restTime: TimeInterval = 0
    var idleTime: TimeInterval = 0
    var isMonitoring: Bool = false
    var lastStateChange: Date = Date()
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "WorkLifeBalance", category: "AppState")
    private var updateTask: Task<Void, Never>?
    private var activityMonitor: ActivityMonitor?
    private var databaseManager: DatabaseManager?
    private var settingsWindow: NSWindow?
    private let focusModeIntegration = FocusModeIntegration.shared
    private let notificationManager = NotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    var formattedWorkTime: String {
        formatTime(workTime)
    }
    
    var formattedRestTime: String {
        formatTime(restTime)
    }
    
    var formattedIdleTime: String {
        formatTime(idleTime)
    }
    
    init() {
        Task { @MainActor in
            await initialize()
        }
    }
    
    deinit {
        cleanup()
    }
    
    private func initialize() async {
        logger.info("Initializing AppStateManager")
        
        do {
            // Initialize components
            databaseManager = try await DatabaseManager.create()
            activityMonitor = ActivityMonitor()
            
            // Load today's data
            await loadTodayData()
            
            // Start monitoring
            await startMonitoring()
            
            // Setup integrations
            await setupIntegrations()
            
            logger.info("AppStateManager initialized successfully")
        } catch {
            logger.error("Failed to initialize AppStateManager: \(error.localizedDescription)")
        }
    }
    
    private func startMonitoring() async {
        guard !isMonitoring else { return }
        
        logger.info("Starting activity monitoring")
        
        // Start activity monitoring
        do {
            try await activityMonitor?.startMonitoring()
        } catch {
            logger.error("Failed to start activity monitoring: \(error.localizedDescription)")
        }
        
        // Start periodic updates using modern async timer
        updateTask = Task {
            await startPeriodicUpdates()
        }
        
        isMonitoring = true
        logger.info("Activity monitoring started")
    }
    
    private func startPeriodicUpdates() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            
            await MainActor.run {
                self.updateState()
                self.updateTime()
            }
        }
    }
    
    private func updateState() {
        // Check for idle
        if let idleTime = self.activityMonitor?.currentIdleTime, idleTime > 300 {
            if self.currentState != .idle {
                self.changeState(to: .idle)
            }
            return
        }
        
        // Check focus mode integration
        if self.focusModeIntegration.isWorkFocusActive {
            if self.currentState != .working {
                self.changeState(to: .working)
            }
            return
        }
        
        // Check active app for work detection
        if UserDefaults.standard.bool(forKey: "autoDetectWork") {
            Task {
                if let appInfo = await self.activityMonitor?.getCurrentApplication() {
                    let workingApps = UserDefaults.standard.string(forKey: "workingApps") ?? ""
                    let appsList = workingApps.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    
                    if let appName = appInfo.name, appsList.contains(appName) {
                        if self.currentState != .working {
                            await MainActor.run {
                                self.changeState(to: .working)
                            }
                        }
                    } else if self.currentState == .working {
                        await MainActor.run {
                            self.changeState(to: .resting)
                        }
                    }
                }
            }
        }
    }
    
    private func changeState(to newState: WorkState) {
        let previousState = currentState
        currentState = newState
        lastStateChange = Date()
        
        logger.info("State changed: \(previousState.description) → \(newState.description)")
        
        // Handle state-specific actions
        Task {
            await handleStateChange(from: previousState, to: newState)
        }
    }
    
    private func updateTime() {
        switch currentState {
        case .working:
            workTime += 1
        case .resting:
            restTime += 1
        case .idle:
            idleTime += 1
        }
        
        // Save to database every minute
        if Int(workTime + restTime + idleTime) % 60 == 0 {
            Task {
                await saveToDatabase()
            }
        }
    }
    
    private func handleStateChange(from previous: WorkState, to current: WorkState) async {
        // Handle notifications
        if previous == .working && current != .working {
            // Work session ended
            let sessionDuration = Date().timeIntervalSince(lastStateChange)
            let productivity = calculateProductivity()
            
            do {
                try await notificationManager.scheduleWorkSessionComplete(
                    workTime: sessionDuration,
                    productivity: productivity
                )
            } catch {
                logger.error("Failed to schedule work session notification: \(error.localizedDescription)")
            }
        }
        
        if current == .idle && previous != .idle {
            // User became idle - schedule alert if needed
            do {
                try await notificationManager.scheduleIdleAlert(idleTime: 0)
            } catch {
                logger.error("Failed to schedule idle alert: \(error.localizedDescription)")
            }
        }
        
        // Check daily goal achievement
        let dailyGoal = UserDefaults.standard.double(forKey: "dailyWorkTimeGoal")
        if dailyGoal > 0 && workTime >= dailyGoal && previous != .working {
            do {
                try await notificationManager.scheduleDailyGoalAchieved()
            } catch {
                logger.error("Failed to schedule daily goal notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateProductivity() -> Double {
        let totalTime = workTime + restTime + idleTime
        guard totalTime > 0 else { return 0 }
        return workTime / totalTime
    }
    
    func startWork() {
        changeState(to: .working)
    }
    
    func startRest() {
        changeState(to: .resting)
    }
    
    func stopMonitoring() async {
        guard isMonitoring else { return }
        
        logger.info("Stopping activity monitoring")
        
        // Cancel update task
        updateTask?.cancel()
        updateTask = nil
        
        // Stop activity monitor
        activityMonitor?.stopMonitoring()
        
        isMonitoring = false
        logger.info("Activity monitoring stopped")
    }
    
    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Work Life Balance Settings"
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView().environmentObject(self))
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func loadTodayData() async {
        self.logger.debug("Loading today's data")
        
        do {
            if let data = try await self.databaseManager?.getTodayData() {
                self.workTime = data.workTime
                self.restTime = data.restTime
                self.idleTime = data.idleTime
                self.logger.debug("Today's data loaded: Work=\(self.workTime)s, Rest=\(self.restTime)s, Idle=\(self.idleTime)s")
            } else {
                // No data for today - start fresh
                self.workTime = 0
                self.restTime = 0
                self.idleTime = 0
                self.logger.debug("No data for today - starting fresh")
            }
        } catch {
            self.logger.error("Failed to load today's data: \(error.localizedDescription)")
        }
    }
    
    private func saveToDatabase() async {
        do {
            try await self.databaseManager?.saveTimeEntry(
                state: self.currentState,
                workTime: self.workTime,
                restTime: self.restTime,
                idleTime: self.idleTime
            )
            self.logger.debug("Time entry saved to database")
        } catch {
            self.logger.error("Failed to save time entry: \(error.localizedDescription)")
        }
    }
    
    func saveCurrentSession() async {
        self.logger.info("Saving current session")
        
        // Save current session data before quitting
        await self.saveToDatabase()
        
        // Stop monitoring
        await self.stopMonitoring()
        
        // Cleanup
        self.cleanup()
        
        self.logger.info("Session data saved. Work: \(self.formattedWorkTime), Rest: \(self.formattedRestTime), Idle: \(self.formattedIdleTime)")
    }
    
    private func setupIntegrations() async {
        // Setup activity monitor events
        if let monitor = self.activityMonitor {
            monitor.activityPublisher
                .sink { [weak self] event in
                    Task { @MainActor in
                        await self?.handleActivityEvent(event)
                    }
                }
                .store(in: &self.cancellables)
        }
        
        // Setup focus mode integration
        self.focusModeIntegration.focusModeChanges
            .sink { [weak self] event in
                Task { @MainActor in
                    await self?.handleFocusModeChange(event)
                }
            }
            .store(in: &self.cancellables)
    }
    
    private func handleActivityEvent(_ event: ActivityEvent) async {
        switch event {
        case .userActivity:
            // Update state based on activity
            updateState()
        case .idleStateChanged(let isIdle):
            if isIdle && currentState != .idle {
                changeState(to: .idle)
            } else if !isIdle && currentState == .idle {
                changeState(to: .resting)
            }
        case .applicationChanged:
            // Update state based on new app
            updateState()
        case .mouseActivity:
            break // Already handled by userActivity
        }
    }
    
    private func handleFocusModeChange(_ event: FocusModeChangeEvent) async {
        if event.isWorkModeActivated {
            changeState(to: .working)
        } else if event.isWorkModeDeactivated {
            changeState(to: .resting)
        }
    }
    
    private nonisolated func cleanup() {
        Task { @MainActor in
            self.updateTask?.cancel()
            self.updateTask = nil
            self.cancellables.removeAll()
            self.logger.info("AppStateManager cleaned up")
        }
    }
}
