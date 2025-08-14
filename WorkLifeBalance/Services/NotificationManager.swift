//
//  NotificationManager.swift
//  WorkLifeBalance
//

import Foundation
import UserNotifications
import OSLog

// MARK: - Notification Types
enum NotificationType: String, CaseIterable, Sendable {
    case breakReminder = "break_reminder"
    case workSessionComplete = "work_session_complete"
    case dailyGoalAchieved = "daily_goal_achieved"
    case weeklyReport = "weekly_report"
    case idleAlert = "idle_alert"
    case productivitySummary = "productivity_summary"
    
    var identifier: String {
        "worklifebalance.\(rawValue)"
    }
    
    var categoryIdentifier: String {
        "worklifebalance.category.\(rawValue)"
    }
}

// MARK: - Notification Content
struct NotificationContent {
    let type: NotificationType
    let title: String
    let body: String
    let sound: UNNotificationSound?
    let userInfo: [String: Any]
    let trigger: UNNotificationTrigger?
    
    init(
        type: NotificationType,
        title: String,
        body: String,
        sound: UNNotificationSound? = .default,
        userInfo: [String: Any] = [:],
        trigger: UNNotificationTrigger? = nil
    ) {
        self.type = type
        self.title = title
        self.body = body
        self.sound = sound
        self.userInfo = userInfo
        self.trigger = trigger
    }
}

// MARK: - Notification Settings
struct NotificationSettings: Sendable, Codable, Equatable {
    let breakRemindersEnabled: Bool
    let workSessionAlertsEnabled: Bool
    let dailyGoalNotificationsEnabled: Bool
    let weeklyReportsEnabled: Bool
    let idleAlertsEnabled: Bool
    let productivitySummaryEnabled: Bool
    
    let breakReminderInterval: TimeInterval // in seconds
    let idleAlertThreshold: TimeInterval // in seconds
    let dailyGoalWorkTime: TimeInterval // in seconds
    
    static let `default` = NotificationSettings(
        breakRemindersEnabled: true,
        workSessionAlertsEnabled: true,
        dailyGoalNotificationsEnabled: true,
        weeklyReportsEnabled: true,
        idleAlertsEnabled: true,
        productivitySummaryEnabled: true,
        breakReminderInterval: 3600, // 1 hour
        idleAlertThreshold: 1800, // 30 minutes
        dailyGoalWorkTime: 28800 // 8 hours
    )
}

// MARK: - Notification Manager Errors
enum NotificationManagerError: Error, LocalizedError {
    case permissionDenied
    case notificationSchedulingFailed(String)
    case invalidSettings(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permissions denied. Please enable notifications in System Settings."
        case .notificationSchedulingFailed(let message):
            return "Failed to schedule notification: \(message)"
        case .invalidSettings(let message):
            return "Invalid notification settings: \(message)"
        }
    }
}

/// Modern notification manager using UserNotifications framework
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject, Sendable {
    
    // MARK: - Published Properties
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var settings: NotificationSettings = .default
    
    // MARK: - Private Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "WorkLifeBalance", category: "Notifications")
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "NotificationSettings"
    
    // MARK: - Singleton
    static let shared = NotificationManager()
    
    nonisolated override init() {
        super.init()
        Task { @MainActor in
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        notificationCenter.delegate = self
        loadSettings()
        await updateAuthorizationStatus()
        await setupNotificationCategories()
        
        logger.info("NotificationManager initialized")
    }
    
    // MARK: - Public API
    
    /// Request notification permissions
    func requestPermissions() async throws {
        logger.info("Requesting notification permissions")
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            await updateAuthorizationStatus()
            
            if granted {
                logger.info("Notification permissions granted")
            } else {
                logger.warning("Notification permissions denied")
                throw NotificationManagerError.permissionDenied
            }
        } catch {
            logger.error("Failed to request notification permissions: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Update notification settings
    func updateSettings(_ newSettings: NotificationSettings) async {
        settings = newSettings
        saveSettings()
        
        // Reschedule notifications with new settings
        await scheduleRecurringNotifications()
        
        logger.info("Notification settings updated")
    }
    
    /// Schedule a one-time notification
    func scheduleNotification(_ content: NotificationContent) async throws {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            throw NotificationManagerError.permissionDenied
        }
        
        let request = createNotificationRequest(for: content)
        
        do {
            try await notificationCenter.add(request)
            logger.debug("Scheduled notification: \(content.type.rawValue)")
        } catch {
            logger.error("Failed to schedule notification: \(error.localizedDescription)")
            throw NotificationManagerError.notificationSchedulingFailed(error.localizedDescription)
        }
    }
    
    /// Schedule break reminder notification
    func scheduleBreakReminder(after interval: TimeInterval) async throws {
        guard settings.breakRemindersEnabled else { return }
        
        let content = NotificationContent(
            type: .breakReminder,
            title: "Time for a Break",
            body: "You've been working for a while. Consider taking a short break to recharge.",
            sound: .default,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: interval,
                repeats: false
            )
        )
        
        try await scheduleNotification(content)
    }
    
    /// Schedule work session completion notification
    func scheduleWorkSessionComplete(workTime: TimeInterval, productivity: Double) async throws {
        guard settings.workSessionAlertsEnabled else { return }
        
        let hours = Int(workTime / 3600)
        let minutes = Int((workTime.truncatingRemainder(dividingBy: 3600)) / 60)
        let productivityText = String(format: "%.0f%%", productivity * 100)
        
        let content = NotificationContent(
            type: .workSessionComplete,
            title: "Work Session Complete",
            body: "Session: \(hours)h \(minutes)m • Productivity: \(productivityText)",
            sound: .default,
            userInfo: [
                "workTime": workTime,
                "productivity": productivity
            ]
        )
        
        try await scheduleNotification(content)
    }
    
    /// Schedule daily goal achievement notification
    func scheduleDailyGoalAchieved() async throws {
        guard settings.dailyGoalNotificationsEnabled else { return }
        
        let content = NotificationContent(
            type: .dailyGoalAchieved,
            title: "Daily Goal Achieved! 🎉",
            body: "Congratulations! You've reached your daily work time goal.",
            sound: .default
        )
        
        try await scheduleNotification(content)
    }
    
    /// Schedule idle alert notification
    func scheduleIdleAlert(idleTime: TimeInterval) async throws {
        guard settings.idleAlertsEnabled else { return }
        
        let minutes = Int(idleTime / 60)
        
        let content = NotificationContent(
            type: .idleAlert,
            title: "Still There?",
            body: "You've been idle for \(minutes) minutes. Click to resume tracking.",
            sound: .default,
            userInfo: ["idleTime": idleTime]
        )
        
        try await scheduleNotification(content)
    }
    
    /// Schedule weekly productivity report
    func scheduleWeeklyReport() async throws {
        guard settings.weeklyReportsEnabled else { return }
        
        // Schedule for Sunday at 7 PM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 19   // 7 PM
        dateComponents.minute = 0
        
        let content = NotificationContent(
            type: .weeklyReport,
            title: "Weekly Productivity Report",
            body: "Your weekly productivity summary is ready to view.",
            trigger: UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
        )
        
        try await scheduleNotification(content)
    }
    
    /// Cancel specific notification type
    func cancelNotifications(of type: NotificationType) async {
        let identifiers = await getPendingNotificationIdentifiers(for: type)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        
        logger.debug("Cancelled \(identifiers.count) notifications of type: \(type.rawValue)")
    }
    
    /// Cancel all notifications
    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        logger.info("Cancelled all pending notifications")
    }
    
    /// Get pending notifications count
    func getPendingNotificationsCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
    }
    
    // MARK: - Recurring Notifications
    
    private func scheduleRecurringNotifications() async {
        // Cancel existing recurring notifications
        await cancelNotifications(of: .weeklyReport)
        
        // Schedule new recurring notifications based on settings
        if settings.weeklyReportsEnabled {
            try? await scheduleWeeklyReport()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createNotificationRequest(for content: NotificationContent) -> UNNotificationRequest {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.body = content.body
        notificationContent.sound = content.sound
        notificationContent.userInfo = content.userInfo
        notificationContent.categoryIdentifier = content.type.categoryIdentifier
        
        return UNNotificationRequest(
            identifier: "\(content.type.identifier)_\(UUID().uuidString)",
            content: notificationContent,
            trigger: content.trigger
        )
    }
    
    private func updateAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    private func getPendingNotificationIdentifiers(for type: NotificationType) async -> [String] {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests
            .filter { $0.identifier.contains(type.identifier) }
            .map { $0.identifier }
    }
    
    private func setupNotificationCategories() async {
        let categories: Set<UNNotificationCategory> = Set(NotificationType.allCases.map { type in
            let actions: [UNNotificationAction] = []
            
            return UNNotificationCategory(
                identifier: type.categoryIdentifier,
                actions: actions,
                intentIdentifiers: [],
                options: []
            )
        })
        
        await notificationCenter.setNotificationCategories(categories)
        logger.debug("Set up \(categories.count) notification categories")
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            settings = savedSettings
            logger.debug("Loaded notification settings from UserDefaults")
        } else {
            settings = .default
            saveSettings()
            logger.debug("Using default notification settings")
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            logger.debug("Saved notification settings to UserDefaults")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when app is in foreground
        completionHandler([.alert, .sound, .badge])
        
        Task { @MainActor in
            logger.debug("Will present notification: \(notification.request.identifier)")
        }
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await handleNotificationResponse(response)
            completionHandler()
        }
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        
        logger.info("Received notification response: \(identifier)")
        
        // Handle different notification types
        if identifier.contains(NotificationType.breakReminder.identifier) {
            // User tapped break reminder - could trigger break mode
            logger.debug("User responded to break reminder")
        } else if identifier.contains(NotificationType.idleAlert.identifier) {
            // User tapped idle alert - resume activity tracking
            logger.debug("User responded to idle alert")
        }
        
        // Post notification for other parts of the app to handle
        NotificationCenter.default.post(
            name: .notificationResponseReceived,
            object: response,
            userInfo: userInfo
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let notificationResponseReceived = Notification.Name("NotificationResponseReceived")
}