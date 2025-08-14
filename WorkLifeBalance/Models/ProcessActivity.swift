//
//  ProcessActivity.swift
//  WorkLifeBalance
//
//  Data model for tracking individual application/process activity
//

import Foundation
import AppKit

// MARK: - ProcessActivity
/// Represents activity data for a specific process/application
struct ProcessActivity: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let processName: String
    let bundleIdentifier: String?
    let applicationName: String
    var totalActiveTime: TimeInterval
    var lastActiveTime: Date
    var activationCount: Int
    var windowTitles: Set<String>
    let firstSeen: Date
    
    // Computed properties
    var averageSessionTime: TimeInterval {
        guard activationCount > 0 else { return 0 }
        return totalActiveTime / Double(activationCount)
    }
    
    var isCurrentlyActive: Bool {
        Date().timeIntervalSince(lastActiveTime) < 5 // Active within last 5 seconds
    }
    
    // Note: NSImage is not Sendable, so this property is marked as nonisolated
    nonisolated var icon: NSImage? {
        guard let bundleId = bundleIdentifier,
              let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: path)
    }
    
    // Initializers
    init(id: UUID = UUID(),
         processName: String,
         bundleIdentifier: String? = nil,
         applicationName: String,
         totalActiveTime: TimeInterval = 0,
         lastActiveTime: Date = Date(),
         activationCount: Int = 0,
         windowTitles: Set<String> = [],
         firstSeen: Date = Date()) {
        self.id = id
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.totalActiveTime = totalActiveTime
        self.lastActiveTime = lastActiveTime
        self.activationCount = activationCount
        self.windowTitles = windowTitles
        self.firstSeen = firstSeen
    }
    
    // Factory method from NSRunningApplication
    static func from(runningApp: NSRunningApplication) -> ProcessActivity {
        return ProcessActivity(
            processName: runningApp.executableURL?.lastPathComponent ?? "Unknown",
            bundleIdentifier: runningApp.bundleIdentifier,
            applicationName: runningApp.localizedName ?? "Unknown App",
            activationCount: 1
        )
    }
    
    // Helper methods
    mutating func recordActivity(duration: TimeInterval, windowTitle: String? = nil) {
        totalActiveTime += duration
        lastActiveTime = Date()
        
        if let title = windowTitle {
            windowTitles.insert(title)
        }
    }
    
    mutating func incrementActivation() {
        activationCount += 1
        lastActiveTime = Date()
    }
    
    func isWorkRelated(workingApps: [String]) -> Bool {
        workingApps.contains { workApp in
            applicationName.localizedCaseInsensitiveContains(workApp) ||
            processName.localizedCaseInsensitiveContains(workApp)
        }
    }
}

// MARK: - ProcessActivitySummary
/// Summary of process activities for reporting
struct ProcessActivitySummary: Codable, Equatable, Sendable {
    let date: Date
    let topApplications: [ProcessActivity]
    let totalApplicationsUsed: Int
    let mostProductiveHour: Int? // Hour of day (0-23)
    let totalFocusTime: TimeInterval // Time spent in work applications
    
    init(from activities: [ProcessActivity], on date: Date) {
        self.date = date
        self.topApplications = Array(activities.sorted { $0.totalActiveTime > $1.totalActiveTime }.prefix(5))
        self.totalApplicationsUsed = activities.count
        self.totalFocusTime = activities.filter { activity in
            // Check if it's a work-related app based on common productivity apps
            let productivityApps = ["Xcode", "Visual Studio", "Terminal", "Safari", "Chrome", "Slack", "Teams"]
            return productivityApps.contains { activity.applicationName.contains($0) }
        }.reduce(0) { $0 + $1.totalActiveTime }
        
        // Calculate most productive hour (simplified - would need hourly data in real implementation)
        self.mostProductiveHour = nil // Would require hourly tracking
    }
}

// MARK: - Codable Support
extension ProcessActivity {
    enum CodingKeys: String, CodingKey {
        case id
        case processName
        case bundleIdentifier
        case applicationName
        case totalActiveTime
        case lastActiveTime
        case activationCount
        case windowTitles
        case firstSeen
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        processName = try container.decode(String.self, forKey: .processName)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        applicationName = try container.decode(String.self, forKey: .applicationName)
        totalActiveTime = try container.decode(TimeInterval.self, forKey: .totalActiveTime)
        lastActiveTime = try container.decode(Date.self, forKey: .lastActiveTime)
        activationCount = try container.decode(Int.self, forKey: .activationCount)
        
        // Handle Set<String> for windowTitles
        let titlesArray = try container.decode([String].self, forKey: .windowTitles)
        windowTitles = Set(titlesArray)
        
        firstSeen = try container.decode(Date.self, forKey: .firstSeen)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(processName, forKey: .processName)
        try container.encodeIfPresent(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(applicationName, forKey: .applicationName)
        try container.encode(totalActiveTime, forKey: .totalActiveTime)
        try container.encode(lastActiveTime, forKey: .lastActiveTime)
        try container.encode(activationCount, forKey: .activationCount)
        
        // Convert Set to Array for encoding
        try container.encode(Array(windowTitles), forKey: .windowTitles)
        
        try container.encode(firstSeen, forKey: .firstSeen)
    }
}