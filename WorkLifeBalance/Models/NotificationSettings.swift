//
//  NotificationSettings.swift
//  WorkLifeBalance
//
//  Data model for notification preferences and management
//

import Foundation
import UserNotifications

// MARK: - AppNotificationSettings
/// Settings for notification preferences
struct AppNotificationSettings: Codable, Equatable {
    var isEnabled: Bool
    var breakReminders: BreakReminderSettings
    var dailySummary: DailySummarySettings
    var productivityAlerts: ProductivityAlertSettings
    var soundEnabled: Bool
    var badgeEnabled: Bool
    
    static let `default` = AppNotificationSettings(
        isEnabled: true,
        breakReminders: BreakReminderSettings(),
        dailySummary: DailySummarySettings(),
        productivityAlerts: ProductivityAlertSettings(),
        soundEnabled: true,
        badgeEnabled: false
    )
}

// MARK: - BreakReminderSettings
struct BreakReminderSettings: Codable, Equatable {
    var isEnabled: Bool
    var intervalMinutes: Int
    var message: String
    var snoozeOptions: [Int] // Minutes
    
    init(isEnabled: Bool = true,
         intervalMinutes: Int = 60,
         message: String = "Time for a break! You've been working for %d minutes.",
         snoozeOptions: [Int] = [5, 10, 15, 30]) {
        self.isEnabled = isEnabled
        self.intervalMinutes = intervalMinutes
        self.message = message
        self.snoozeOptions = snoozeOptions
    }
    
    func formattedMessage(workMinutes: Int) -> String {
        String(format: message, workMinutes)
    }
}

// MARK: - DailySummarySettings
struct DailySummarySettings: Codable, Equatable {
    var isEnabled: Bool
    var summaryTime: Date // Time of day to send summary
    var includedMetrics: Set<SummaryMetric>
    
    init(isEnabled: Bool = true,
         summaryTime: Date = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date(),
         includedMetrics: Set<SummaryMetric> = Set(SummaryMetric.allCases)) {
        self.isEnabled = isEnabled
        self.summaryTime = summaryTime
        self.includedMetrics = includedMetrics
    }
}

enum SummaryMetric: String, Codable, CaseIterable {
    case totalWorkTime = "total_work_time"
    case totalRestTime = "total_rest_time"
    case productivityScore = "productivity_score"
    case topApplications = "top_applications"
    case numberOfSessions = "number_of_sessions"
    case longestWorkSession = "longest_work_session"
    
    var displayName: String {
        switch self {
        case .totalWorkTime: return "Total Work Time"
        case .totalRestTime: return "Total Rest Time"
        case .productivityScore: return "Productivity Score"
        case .topApplications: return "Top Applications"
        case .numberOfSessions: return "Number of Sessions"
        case .longestWorkSession: return "Longest Work Session"
        }
    }
}

// MARK: - ProductivityAlertSettings
struct ProductivityAlertSettings: Codable, Equatable {
    var isEnabled: Bool
    var lowProductivityThreshold: Double // Percentage
    var highProductivityThreshold: Double // Percentage
    var checkIntervalMinutes: Int
    
    init(isEnabled: Bool = false,
         lowProductivityThreshold: Double = 40.0,
         highProductivityThreshold: Double = 90.0,
         checkIntervalMinutes: Int = 120) {
        self.isEnabled = isEnabled
        self.lowProductivityThreshold = lowProductivityThreshold
        self.highProductivityThreshold = highProductivityThreshold
        self.checkIntervalMinutes = checkIntervalMinutes
    }
}