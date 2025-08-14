//
//  ApplicationProfile.swift
//  WorkLifeBalance
//
//  Data model for managing monitored applications and their categorization
//

import Foundation
import AppKit

// MARK: - ApplicationCategory
enum ApplicationCategory: String, Codable, CaseIterable {
    case productivity = "productivity"
    case communication = "communication"
    case development = "development"
    case design = "design"
    case entertainment = "entertainment"
    case social = "social"
    case utilities = "utilities"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .productivity: return "Productivity"
        case .communication: return "Communication"
        case .development: return "Development"
        case .design: return "Design"
        case .entertainment: return "Entertainment"
        case .social: return "Social Media"
        case .utilities: return "Utilities"
        case .other: return "Other"
        }
    }
    
    var color: NSColor {
        switch self {
        case .productivity: return .systemGreen
        case .communication: return .systemBlue
        case .development: return .systemPurple
        case .design: return .systemPink
        case .entertainment: return .systemOrange
        case .social: return .systemYellow
        case .utilities: return .systemGray
        case .other: return .systemBrown
        }
    }
    
    var isWorkRelated: Bool {
        switch self {
        case .productivity, .communication, .development, .design, .utilities:
            return true
        case .entertainment, .social, .other:
            return false
        }
    }
}

// MARK: - ApplicationProfile
/// Profile for a monitored application
struct ApplicationProfile: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let bundleIdentifier: String?
    var category: ApplicationCategory
    var isWorkRelated: Bool
    var customRules: ApplicationRules
    var icon: Data? // Cached icon data
    let dateAdded: Date
    var lastUsed: Date?
    var totalUsageTime: TimeInterval
    
    // Computed properties
    var displayIcon: NSImage? {
        if let iconData = icon {
            return NSImage(data: iconData)
        } else if let bundleId = bundleIdentifier {
            return NSWorkspace.shared.icon(forFile: 
                NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleId) ?? ""
            )
        }
        return nil
    }
    
    var isActive: Bool {
        guard let lastUsed = lastUsed else { return false }
        return Date().timeIntervalSince(lastUsed) < 300 // Active in last 5 minutes
    }
    
    // Initializers
    init(id: UUID = UUID(),
         name: String,
         bundleIdentifier: String? = nil,
         category: ApplicationCategory = .other,
         isWorkRelated: Bool? = nil,
         customRules: ApplicationRules = ApplicationRules(),
         icon: Data? = nil,
         dateAdded: Date = Date(),
         lastUsed: Date? = nil,
         totalUsageTime: TimeInterval = 0) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.category = category
        self.isWorkRelated = isWorkRelated ?? category.isWorkRelated
        self.customRules = customRules
        self.icon = icon
        self.dateAdded = dateAdded
        self.lastUsed = lastUsed
        self.totalUsageTime = totalUsageTime
    }
    
    // Factory method from NSRunningApplication
    static func from(runningApp: NSRunningApplication, category: ApplicationCategory = .other) -> ApplicationProfile {
        let iconData = runningApp.icon?.tiffRepresentation
        
        return ApplicationProfile(
            name: runningApp.localizedName ?? "Unknown",
            bundleIdentifier: runningApp.bundleIdentifier,
            category: category,
            icon: iconData
        )
    }
    
    // Helper methods
    mutating func recordUsage(duration: TimeInterval) {
        totalUsageTime += duration
        lastUsed = Date()
    }
    
    func matchesRules(windowTitle: String? = nil, url: String? = nil) -> Bool {
        // Check window title rules
        if let title = windowTitle {
            if !customRules.includedWindowTitles.isEmpty {
                let matches = customRules.includedWindowTitles.contains { pattern in
                    title.localizedCaseInsensitiveContains(pattern)
                }
                if !matches { return false }
            }
            
            if customRules.excludedWindowTitles.contains(where: { title.localizedCaseInsensitiveContains($0) }) {
                return false
            }
        }
        
        // Check URL rules (for browsers)
        if let url = url {
            if !customRules.includedURLs.isEmpty {
                let matches = customRules.includedURLs.contains { pattern in
                    url.localizedCaseInsensitiveContains(pattern)
                }
                if !matches { return false }
            }
            
            if customRules.excludedURLs.contains(where: { url.localizedCaseInsensitiveContains($0) }) {
                return false
            }
        }
        
        return true
    }
}

// MARK: - ApplicationRules
/// Custom rules for application categorization
struct ApplicationRules: Codable, Equatable, Hashable {
    var includedWindowTitles: [String]
    var excludedWindowTitles: [String]
    var includedURLs: [String] // For browsers
    var excludedURLs: [String] // For browsers
    var timeBasedRules: [TimeBasedRule]
    
    init(includedWindowTitles: [String] = [],
         excludedWindowTitles: [String] = [],
         includedURLs: [String] = [],
         excludedURLs: [String] = [],
         timeBasedRules: [TimeBasedRule] = []) {
        self.includedWindowTitles = includedWindowTitles
        self.excludedWindowTitles = excludedWindowTitles
        self.includedURLs = includedURLs
        self.excludedURLs = excludedURLs
        self.timeBasedRules = timeBasedRules
    }
    
    func isWorkRelatedAtTime(_ date: Date) -> Bool? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        
        for rule in timeBasedRules {
            if rule.matches(components: components) {
                return rule.isWorkRelated
            }
        }
        
        return nil // No time-based rule applies
    }
}

// MARK: - TimeBasedRule
/// Rule for time-based categorization
struct TimeBasedRule: Codable, Equatable, Hashable {
    var startTime: DateComponents // hour and minute
    var endTime: DateComponents // hour and minute
    var daysOfWeek: Set<Int> // 1 = Sunday, 7 = Saturday
    var isWorkRelated: Bool
    
    func matches(components: DateComponents) -> Bool {
        // Check day of week
        if let weekday = components.weekday, !daysOfWeek.contains(weekday) {
            return false
        }
        
        // Check time range
        guard let hour = components.hour,
              let minute = components.minute,
              let startHour = startTime.hour,
              let startMinute = startTime.minute,
              let endHour = endTime.hour,
              let endMinute = endTime.minute else {
            return false
        }
        
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        if startMinutes <= endMinutes {
            // Normal range (e.g., 9:00 - 17:00)
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight range (e.g., 22:00 - 02:00)
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
}

// MARK: - ApplicationProfileManager
/// Manager for application profiles
class ApplicationProfileManager: ObservableObject {
    @Published var profiles: [ApplicationProfile] = []
    
    private let storageKey = "application_profiles"
    
    init() {
        loadProfiles()
    }
    
    func addProfile(_ profile: ApplicationProfile) {
        if !profiles.contains(where: { $0.bundleIdentifier == profile.bundleIdentifier }) {
            profiles.append(profile)
            saveProfiles()
        }
    }
    
    func updateProfile(_ profile: ApplicationProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
        }
    }
    
    func removeProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        saveProfiles()
    }
    
    func getProfile(for bundleIdentifier: String) -> ApplicationProfile? {
        profiles.first { $0.bundleIdentifier == bundleIdentifier }
    }
    
    func getProfile(for app: NSRunningApplication) -> ApplicationProfile? {
        if let bundleId = app.bundleIdentifier {
            return getProfile(for: bundleId)
        }
        return profiles.first { $0.name == app.localizedName }
    }
    
    func categorizeApplication(_ app: NSRunningApplication) -> ApplicationCategory {
        if let profile = getProfile(for: app) {
            return profile.category
        }
        
        // Auto-categorize based on common patterns
        let name = app.localizedName?.lowercased() ?? ""
        
        if name.contains("xcode") || name.contains("visual studio") || name.contains("terminal") {
            return .development
        } else if name.contains("slack") || name.contains("teams") || name.contains("zoom") {
            return .communication
        } else if name.contains("figma") || name.contains("sketch") || name.contains("photoshop") {
            return .design
        } else if name.contains("safari") || name.contains("chrome") || name.contains("firefox") {
            return .productivity // Browsers can be either, default to productivity
        } else if name.contains("spotify") || name.contains("music") || name.contains("netflix") {
            return .entertainment
        }
        
        return .other
    }
    
    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([ApplicationProfile].self, from: data) {
            profiles = loaded
        } else {
            // Load default profiles
            loadDefaultProfiles()
        }
    }
    
    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadDefaultProfiles() {
        // Common productivity apps
        let defaultProfiles = [
            ApplicationProfile(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", category: .development),
            ApplicationProfile(name: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode", category: .development),
            ApplicationProfile(name: "Terminal", bundleIdentifier: "com.apple.Terminal", category: .development),
            ApplicationProfile(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap", category: .communication),
            ApplicationProfile(name: "Microsoft Teams", bundleIdentifier: "com.microsoft.teams", category: .communication),
            ApplicationProfile(name: "Safari", bundleIdentifier: "com.apple.Safari", category: .productivity),
            ApplicationProfile(name: "Google Chrome", bundleIdentifier: "com.google.Chrome", category: .productivity),
            ApplicationProfile(name: "Figma", bundleIdentifier: "com.figma.Desktop", category: .design),
            ApplicationProfile(name: "Spotify", bundleIdentifier: "com.spotify.client", category: .entertainment)
        ]
        
        profiles = defaultProfiles
        saveProfiles()
    }
}