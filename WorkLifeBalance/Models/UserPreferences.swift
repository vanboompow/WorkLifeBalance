//
//  UserPreferences.swift
//  WorkLifeBalance
//
//  Comprehensive user preferences and settings model
//

import Foundation
import SwiftUI

// MARK: - UserPreferences
/// Complete user preferences for the application
struct UserPreferences: Codable, Equatable, Sendable {
    var general: GeneralPreferences
    var tracking: TrackingPreferences
    var appearance: AppearancePreferences
    var notifications: NotificationSettings
    var export: ExportPreferences
    var advanced: AdvancedPreferences
    
    static let `default` = UserPreferences(
        general: GeneralPreferences(),
        tracking: TrackingPreferences(),
        appearance: AppearancePreferences(),
        notifications: NotificationSettings.default,
        export: ExportPreferences(),
        advanced: AdvancedPreferences()
    )
}

// MARK: - GeneralPreferences
struct GeneralPreferences: Codable, Equatable, Sendable {
    var launchAtLogin: Bool
    var showInDock: Bool
    var showMenuBarIcon: Bool
    var checkForUpdates: Bool
    var language: String // Language code
    
    init(launchAtLogin: Bool = false,
         showInDock: Bool = false,
         showMenuBarIcon: Bool = true,
         checkForUpdates: Bool = true,
         language: String = "en") {
        self.launchAtLogin = launchAtLogin
        self.showInDock = showInDock
        self.showMenuBarIcon = showMenuBarIcon
        self.checkForUpdates = checkForUpdates
        self.language = language
    }
}

// MARK: - TrackingPreferences
struct TrackingPreferences: Codable, Equatable, Sendable {
    var autoDetectWork: Bool
    var idleThresholdMinutes: Int
    var workingApps: [String]
    var trackingMode: TrackingMode
    var minimumSessionDuration: TimeInterval // Seconds
    var mergeShortBreaks: Bool
    var mergeThresholdMinutes: Int
    
    init(autoDetectWork: Bool = true,
         idleThresholdMinutes: Int = 5,
         workingApps: [String] = ["Xcode", "Visual Studio Code", "Terminal"],
         trackingMode: TrackingMode = .automatic,
         minimumSessionDuration: TimeInterval = 60,
         mergeShortBreaks: Bool = true,
         mergeThresholdMinutes: Int = 2) {
        self.autoDetectWork = autoDetectWork
        self.idleThresholdMinutes = idleThresholdMinutes
        self.workingApps = workingApps
        self.trackingMode = trackingMode
        self.minimumSessionDuration = minimumSessionDuration
        self.mergeShortBreaks = mergeShortBreaks
        self.mergeThresholdMinutes = mergeThresholdMinutes
    }
}

enum TrackingMode: String, Codable, CaseIterable, Sendable {
    case automatic = "automatic"
    case manual = "manual"
    case hybrid = "hybrid" // Automatic with manual override
    
    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .manual: return "Manual"
        case .hybrid: return "Hybrid"
        }
    }
    
    var description: String {
        switch self {
        case .automatic:
            return "Automatically detect work/rest based on active applications"
        case .manual:
            return "Manually start and stop work/rest periods"
        case .hybrid:
            return "Automatic detection with ability to manually override"
        }
    }
}

// MARK: - AppearancePreferences
struct AppearancePreferences: Codable, Equatable, Sendable {
    var theme: AppTheme
    var accentColor: String // Hex color
    var menuBarIconStyle: MenuBarIconStyle
    var showTimeInMenuBar: Bool
    var timeFormat: TimeFormat
    var chartStyle: ChartStyle
    
    init(theme: AppTheme = .system,
         accentColor: String = "#007AFF",
         menuBarIconStyle: MenuBarIconStyle = .dynamic,
         showTimeInMenuBar: Bool = false,
         timeFormat: TimeFormat = .abbreviated,
         chartStyle: ChartStyle = .modern) {
        self.theme = theme
        self.accentColor = accentColor
        self.menuBarIconStyle = menuBarIconStyle
        self.showTimeInMenuBar = showTimeInMenuBar
        self.timeFormat = timeFormat
        self.chartStyle = chartStyle
    }
}

enum AppTheme: String, Codable, CaseIterable, Sendable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum MenuBarIconStyle: String, Codable, CaseIterable, Sendable {
    case `static` = "static"
    case dynamic = "dynamic" // Changes based on state
    case minimal = "minimal"
    case detailed = "detailed" // Shows time
    
    var displayName: String {
        switch self {
        case .`static`: return "Static"
        case .dynamic: return "Dynamic"
        case .minimal: return "Minimal"
        case .detailed: return "Detailed"
        }
    }
}

enum TimeFormat: String, Codable, CaseIterable, Sendable {
    case abbreviated = "abbreviated" // 1h 30m
    case full = "full" // 1 hour 30 minutes
    case compact = "compact" // 1:30
    case seconds = "seconds" // 01:30:45
    
    var displayName: String {
        switch self {
        case .abbreviated: return "Abbreviated (1h 30m)"
        case .full: return "Full (1 hour 30 minutes)"
        case .compact: return "Compact (1:30)"
        case .seconds: return "With Seconds (01:30:45)"
        }
    }
}

enum ChartStyle: String, Codable, CaseIterable, Sendable {
    case classic = "classic"
    case modern = "modern"
    case minimal = "minimal"
    case detailed = "detailed"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .modern: return "Modern"
        case .minimal: return "Minimal"
        case .detailed: return "Detailed"
        }
    }
}

// MARK: - ExportPreferences
struct ExportPreferences: Codable, Equatable, Sendable {
    var defaultFormat: ExportFormat
    var includeCharts: Bool
    var includeSummary: Bool
    var includeDetails: Bool
    var dateFormat: String
    var timezone: String
    
    init(defaultFormat: ExportFormat = .csv,
         includeCharts: Bool = true,
         includeSummary: Bool = true,
         includeDetails: Bool = false,
         dateFormat: String = "yyyy-MM-dd",
         timezone: String = TimeZone.current.identifier) {
        self.defaultFormat = defaultFormat
        self.includeCharts = includeCharts
        self.includeSummary = includeSummary
        self.includeDetails = includeDetails
        self.dateFormat = dateFormat
        self.timezone = timezone
    }
}

enum ExportFormat: String, Codable, CaseIterable, Sendable {
    case csv = "csv"
    case json = "json"
    case pdf = "pdf"
    case html = "html"
    case excel = "excel"
    
    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .json: return "JSON"
        case .pdf: return "PDF"
        case .html: return "HTML"
        case .excel: return "Excel"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .excel: return "xlsx"
        default: return rawValue
        }
    }
}

// MARK: - AdvancedPreferences
struct AdvancedPreferences: Codable, Equatable, Sendable {
    var dataRetentionDays: Int
    var enableAnalytics: Bool
    var debugMode: Bool
    var logLevel: LogLevel
    var databasePath: String?
    var backupEnabled: Bool
    var backupIntervalDays: Int
    var privacyMode: Bool // Blur sensitive information
    
    init(dataRetentionDays: Int = 365,
         enableAnalytics: Bool = false,
         debugMode: Bool = false,
         logLevel: LogLevel = .info,
         databasePath: String? = nil,
         backupEnabled: Bool = true,
         backupIntervalDays: Int = 7,
         privacyMode: Bool = false) {
        self.dataRetentionDays = dataRetentionDays
        self.enableAnalytics = enableAnalytics
        self.debugMode = debugMode
        self.logLevel = logLevel
        self.databasePath = databasePath
        self.backupEnabled = backupEnabled
        self.backupIntervalDays = backupIntervalDays
        self.privacyMode = privacyMode
    }
}

enum LogLevel: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case error = "error"
    case warning = "warning"
    case info = "info"
    case debug = "debug"
    case verbose = "verbose"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Info"
        case .debug: return "Debug"
        case .verbose: return "Verbose"
        }
    }
}

// MARK: - PreferencesManager
/// Manager for user preferences
@MainActor
final class PreferencesManager: ObservableObject, Sendable {
    static let shared = PreferencesManager()
    
    @Published var preferences: UserPreferences {
        didSet {
            savePreferences()
            applyPreferences()
        }
    }
    
    private let storageKey = "user_preferences"
    
    private init() {
        self.preferences = Self.loadPreferences() ?? .default
        applyPreferences()
    }
    
    private static func loadPreferences() -> UserPreferences? {
        guard let data = UserDefaults.standard.data(forKey: "user_preferences"),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return nil
        }
        return preferences
    }
    
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func applyPreferences() {
        // Apply theme
        switch preferences.appearance.theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
        
        // Apply other preferences
        if preferences.general.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // Update notification settings
        Task {
            await NotificationManager.shared.updateSettings(preferences.notifications)
        }
    }
    
    func resetToDefaults() {
        preferences = .default
    }
    
    func exportPreferences(to url: URL) throws {
        let data = try JSONEncoder().encode(preferences)
        try data.write(to: url)
    }
    
    func importPreferences(from url: URL) throws {
        let data = try Data(contentsOf: url)
        preferences = try JSONDecoder().decode(UserPreferences.self, from: data)
    }
}