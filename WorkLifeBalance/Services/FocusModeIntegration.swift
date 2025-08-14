//
//  FocusModeIntegration.swift
//  WorkLifeBalance
//

import Foundation
import Combine
import OSLog

// MARK: - Focus Mode State
enum FocusMode: String, CaseIterable, Sendable {
    case work = "com.apple.focus.work"
    case personalTime = "com.apple.focus.personal-time" 
    case doNotDisturb = "com.apple.focus.do-not-disturb"
    case sleep = "com.apple.focus.sleep"
    case driving = "com.apple.focus.driving"
    case fitness = "com.apple.focus.fitness"
    case mindfulness = "com.apple.focus.mindfulness"
    case reading = "com.apple.focus.reading"
    case gaming = "com.apple.focus.gaming"
    case custom = "custom"
    case inactive = "inactive"
    
    var displayName: String {
        switch self {
        case .work:
            return "Work"
        case .personalTime:
            return "Personal Time"
        case .doNotDisturb:
            return "Do Not Disturb"
        case .sleep:
            return "Sleep"
        case .driving:
            return "Driving"
        case .fitness:
            return "Fitness"
        case .mindfulness:
            return "Mindfulness"
        case .reading:
            return "Reading"
        case .gaming:
            return "Gaming"
        case .custom:
            return "Custom Focus"
        case .inactive:
            return "No Focus"
        }
    }
    
    var workRelated: Bool {
        switch self {
        case .work:
            return true
        case .personalTime, .doNotDisturb, .sleep, .driving, .fitness, .mindfulness, .reading, .gaming:
            return false
        case .custom, .inactive:
            return false // Could be configurable in the future
        }
    }
}

// MARK: - Focus Mode Info
struct FocusModeInfo: Sendable, Equatable {
    let mode: FocusMode
    let isActive: Bool
    let displayName: String
    let startTime: Date?
    let estimatedEndTime: Date?
    
    init(mode: FocusMode, isActive: Bool = false, startTime: Date? = nil, estimatedEndTime: Date? = nil) {
        self.mode = mode
        self.isActive = isActive
        self.displayName = mode.displayName
        self.startTime = startTime
        self.estimatedEndTime = estimatedEndTime
    }
    
    static let inactive = FocusModeInfo(mode: .inactive, isActive: false)
}

// MARK: - Focus Mode Change Event
struct FocusModeChangeEvent: Sendable {
    let previousMode: FocusModeInfo
    let currentMode: FocusModeInfo
    let timestamp: Date
    let automatic: Bool
    
    var isWorkModeActivated: Bool {
        !previousMode.mode.workRelated && currentMode.mode.workRelated
    }
    
    var isWorkModeDeactivated: Bool {
        previousMode.mode.workRelated && !currentMode.mode.workRelated
    }
}

// MARK: - Focus Mode Integration Errors
enum FocusModeError: Error, LocalizedError {
    case notSupported(String)
    case permissionDenied(String)
    case queryFailed(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notSupported(let message):
            return "Focus mode not supported: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .queryFailed(let message):
            return "Focus mode query failed: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

/// Focus mode integration for detecting macOS Focus states and adapting work tracking accordingly
@MainActor
final class FocusModeIntegration: ObservableObject, Sendable {
    
    // MARK: - Published Properties
    @Published private(set) var currentFocusMode: FocusModeInfo = .inactive
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var isSupported: Bool = false
    
    // MARK: - Publishers
    private let focusModeChangeSubject = PassthroughSubject<FocusModeChangeEvent, Never>()
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "WorkLifeBalance", category: "FocusMode")
    private var focusModeObserver: NSObjectProtocol?
    private var pollingTimer: Timer?
    private var lastKnownMode: FocusModeInfo = .inactive
    private let userDefaults = UserDefaults.standard
    
    // Configuration
    private let pollingInterval: TimeInterval = 30 // seconds
    private let focusModeIntegrationKey = "FocusModeIntegrationEnabled"
    
    // MARK: - Singleton
    static let shared = FocusModeIntegration()
    
    nonisolated init() {
        Task { @MainActor in
            await initialize()
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        logger.info("Initializing Focus Mode Integration")
        
        // Check if Focus Mode is supported (macOS 12+)
        isSupported = await checkFocusModeSupport()
        
        if isSupported {
            // Load initial focus mode state
            await updateFocusMode()
            
            // Start monitoring if enabled
            if userDefaults.bool(forKey: focusModeIntegrationKey) {
                await startMonitoring()
            }
            
            logger.info("Focus Mode Integration initialized - Supported: \(isSupported)")
        } else {
            logger.warning("Focus Mode Integration not supported on this macOS version")
        }
    }
    
    // MARK: - Public API
    
    /// Publisher for focus mode change events
    nonisolated var focusModeChanges: AnyPublisher<FocusModeChangeEvent, Never> {
        focusModeChangeSubject.eraseToAnyPublisher()
    }
    
    /// Start monitoring focus mode changes
    func startMonitoring() async {
        guard isSupported else {
            logger.warning("Cannot start monitoring - Focus Mode not supported")
            return
        }
        
        guard !isMonitoring else {
            logger.debug("Focus mode monitoring already active")
            return
        }
        
        logger.info("Starting Focus Mode monitoring")
        
        // Set up distributed notification observer for focus mode changes
        setupFocusModeObserver()
        
        // Set up polling as fallback
        setupPollingTimer()
        
        isMonitoring = true
        userDefaults.set(true, forKey: focusModeIntegrationKey)
        
        logger.info("Focus Mode monitoring started")
    }
    
    /// Stop monitoring focus mode changes
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("Stopping Focus Mode monitoring")
        
        // Remove notification observer
        if let observer = focusModeObserver {
            DistributedNotificationCenter.default.removeObserver(observer)
            focusModeObserver = nil
        }
        
        // Stop polling timer
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        isMonitoring = false
        userDefaults.set(false, forKey: focusModeIntegrationKey)
        
        logger.info("Focus Mode monitoring stopped")
    }
    
    /// Toggle monitoring state
    func toggleMonitoring() async {
        if isMonitoring {
            stopMonitoring()
        } else {
            await startMonitoring()
        }
    }
    
    /// Manually refresh current focus mode state
    func refreshFocusMode() async {
        await updateFocusMode()
    }
    
    /// Check if a specific focus mode is currently active
    func isFocusModeActive(_ mode: FocusMode) -> Bool {
        return currentFocusMode.mode == mode && currentFocusMode.isActive
    }
    
    /// Check if any work-related focus mode is active
    var isWorkFocusActive: Bool {
        currentFocusMode.isActive && currentFocusMode.mode.workRelated
    }
    
    /// Stream of focus mode states
    nonisolated func focusModeStates() -> AsyncStream<FocusModeInfo> {
        AsyncStream { continuation in
            let cancellable = focusModeChangeSubject
                .map { $0.currentMode }
                .sink { mode in
                    continuation.yield(mode)
                }
            
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func checkFocusModeSupport() async -> Bool {
        // Focus modes were introduced in macOS 12.0 (Monterey)
        if #available(macOS 12.0, *) {
            return true
        } else {
            return false
        }
    }
    
    private func setupFocusModeObserver() {
        // Remove existing observer
        if let observer = focusModeObserver {
            DistributedNotificationCenter.default.removeObserver(observer)
        }
        
        // Listen for focus mode changes via distributed notifications
        focusModeObserver = DistributedNotificationCenter.default.addObserver(
            forName: .init("com.apple.donotdisturb.state.changed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleFocusModeNotification(notification)
            }
        }
        
        logger.debug("Set up Focus Mode distributed notification observer")
    }
    
    private func setupPollingTimer() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateFocusMode()
            }
        }
        
        logger.debug("Set up Focus Mode polling timer (interval: \(pollingInterval)s)")
    }
    
    private func handleFocusModeNotification(_ notification: Notification) async {
        logger.debug("Received Focus Mode change notification")
        await updateFocusMode()
    }
    
    private func updateFocusMode() async {
        let newMode = await detectCurrentFocusMode()
        
        // Check if mode actually changed
        if newMode != currentFocusMode {
            let previousMode = currentFocusMode
            currentFocusMode = newMode
            lastKnownMode = newMode
            
            // Create change event
            let changeEvent = FocusModeChangeEvent(
                previousMode: previousMode,
                currentMode: newMode,
                timestamp: Date(),
                automatic: true
            )
            
            // Publish change event
            focusModeChangeSubject.send(changeEvent)
            
            logger.info("Focus Mode changed: \(previousMode.mode.rawValue) → \(newMode.mode.rawValue)")
        }
    }
    
    private func detectCurrentFocusMode() async -> FocusModeInfo {
        // This is a simplified implementation since macOS doesn't provide
        // a direct API to query the current focus mode state
        
        // Method 1: Try to detect via UserDefaults (may work for some cases)
        if let focusMode = detectViaDNDUserDefaults() {
            return focusMode
        }
        
        // Method 2: Try to detect via NSRunningApplication and heuristics
        if let focusMode = detectViaHeuristics() {
            return focusMode
        }
        
        // Method 3: Check system preferences and running processes
        if let focusMode = await detectViaSystemState() {
            return focusMode
        }
        
        // Fallback: No focus mode active
        return FocusModeInfo.inactive
    }
    
    private func detectViaDNDUserDefaults() -> FocusModeInfo? {
        // Check if Do Not Disturb is enabled via user defaults
        // This is a heuristic approach and may not be 100% reliable
        
        let dndDefaults = UserDefaults(suiteName: "com.apple.notificationcenterui")
        let isDNDEnabled = dndDefaults?.bool(forKey: "doNotDisturb") ?? false
        
        if isDNDEnabled {
            return FocusModeInfo(
                mode: .doNotDisturb,
                isActive: true,
                startTime: Date() // Approximate
            )
        }
        
        return nil
    }
    
    private func detectViaHeuristics() -> FocusModeInfo? {
        // Use various system heuristics to detect focus modes
        
        // Check for Work focus mode indicators
        if isWorkTimeHeuristic() {
            return FocusModeInfo(
                mode: .work,
                isActive: true,
                startTime: Date()
            )
        }
        
        // Check for Sleep focus mode (typically during night hours)
        if isSleepTimeHeuristic() {
            return FocusModeInfo(
                mode: .sleep,
                isActive: true,
                startTime: Date()
            )
        }
        
        return nil
    }
    
    private func detectViaSystemState() async -> FocusModeInfo? {
        // This would require more advanced system inspection
        // For now, return nil as a placeholder
        return nil
    }
    
    private func isWorkTimeHeuristic() -> Bool {
        // Simple heuristic: work hours are 9 AM to 5 PM on weekdays
        let calendar = Calendar.current
        let now = Date()
        
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        // Monday (2) through Friday (6)
        let isWeekday = weekday >= 2 && weekday <= 6
        
        // 9 AM to 5 PM
        let isWorkHours = hour >= 9 && hour < 17
        
        return isWeekday && isWorkHours
    }
    
    private func isSleepTimeHeuristic() -> Bool {
        // Simple heuristic: sleep hours are 10 PM to 7 AM
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        return hour >= 22 || hour <= 7
    }
    
    // MARK: - Configuration
    
    /// Check if focus mode integration is enabled
    var isEnabled: Bool {
        userDefaults.bool(forKey: focusModeIntegrationKey)
    }
    
    /// Enable or disable focus mode integration
    func setEnabled(_ enabled: Bool) async {
        if enabled && !isMonitoring {
            await startMonitoring()
        } else if !enabled && isMonitoring {
            stopMonitoring()
        }
    }
    
    /// Get configuration for focus mode integration
    func getConfiguration() -> FocusModeConfiguration {
        FocusModeConfiguration(
            isEnabled: isEnabled,
            isSupported: isSupported,
            isMonitoring: isMonitoring,
            currentMode: currentFocusMode,
            pollingInterval: pollingInterval
        )
    }
}

// MARK: - Focus Mode Configuration
struct FocusModeConfiguration: Sendable {
    let isEnabled: Bool
    let isSupported: Bool
    let isMonitoring: Bool
    let currentMode: FocusModeInfo
    let pollingInterval: TimeInterval
    
    var description: String {
        if !isSupported {
            return "Not supported on this macOS version"
        }
        
        let status = isEnabled ? "Enabled" : "Disabled"
        let monitoring = isMonitoring ? "Monitoring" : "Not monitoring"
        let mode = currentMode.isActive ? currentMode.displayName : "No focus active"
        
        return "\(status) • \(monitoring) • \(mode)"
    }
}