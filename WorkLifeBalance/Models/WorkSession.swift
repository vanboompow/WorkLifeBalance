//
//  WorkSession.swift
//  WorkLifeBalance
//
//  Data model for individual work/rest/idle sessions
//

import Foundation

// MARK: - SessionType
enum SessionType: String, Codable, CaseIterable, Sendable {
    case work = "work"
    case rest = "rest"
    case idle = "idle"
    
    var displayName: String {
        switch self {
        case .work: return "Working"
        case .rest: return "Resting"
        case .idle: return "Idle"
        }
    }
    
    var color: String {
        switch self {
        case .work: return "green"
        case .rest: return "blue"
        case .idle: return "gray"
        }
    }
}

// MARK: - WorkSession
/// Represents a single work, rest, or idle session
struct WorkSession: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let type: SessionType
    let startTime: Date
    var endTime: Date?
    var notes: String?
    var associatedApps: [String]
    
    // Computed properties
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var isActive: Bool {
        endTime == nil
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: startTime)
        
        if let end = endTime {
            let endStr = formatter.string(from: end)
            return "\(start) - \(endStr)"
        } else {
            return "\(start) - ongoing"
        }
    }
    
    // Initializers
    init(id: UUID = UUID(),
         type: SessionType,
         startTime: Date = Date(),
         endTime: Date? = nil,
         notes: String? = nil,
         associatedApps: [String] = []) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.associatedApps = associatedApps
    }
    
    // Helper methods
    mutating func end(at time: Date = Date()) {
        guard endTime == nil else { return }
        endTime = time
    }
    
    mutating func addAssociatedApp(_ appName: String) {
        if !associatedApps.contains(appName) {
            associatedApps.append(appName)
        }
    }
    
    func overlaps(with other: WorkSession) -> Bool {
        let thisEnd = endTime ?? Date()
        let otherEnd = other.endTime ?? Date()
        
        return startTime < otherEnd && thisEnd > other.startTime
    }
    
    func contains(date: Date) -> Bool {
        let end = endTime ?? Date()
        return date >= startTime && date <= end
    }
}

// MARK: - WorkSessionAnalytics
/// Analytics for a collection of work sessions
struct WorkSessionAnalytics: Sendable {
    let sessions: [WorkSession]
    
    var totalWorkTime: TimeInterval {
        sessions.filter { $0.type == .work }.reduce(0) { $0 + $1.duration }
    }
    
    var totalRestTime: TimeInterval {
        sessions.filter { $0.type == .rest }.reduce(0) { $0 + $1.duration }
    }
    
    var totalIdleTime: TimeInterval {
        sessions.filter { $0.type == .idle }.reduce(0) { $0 + $1.duration }
    }
    
    var averageWorkSessionLength: TimeInterval {
        let workSessions = sessions.filter { $0.type == .work }
        guard !workSessions.isEmpty else { return 0 }
        return totalWorkTime / Double(workSessions.count)
    }
    
    var averageRestSessionLength: TimeInterval {
        let restSessions = sessions.filter { $0.type == .rest }
        guard !restSessions.isEmpty else { return 0 }
        return totalRestTime / Double(restSessions.count)
    }
    
    var longestWorkStreak: TimeInterval {
        sessions.filter { $0.type == .work }.map { $0.duration }.max() ?? 0
    }
    
    var numberOfSessions: Int {
        sessions.count
    }
    
    var mostUsedApps: [String: Int] {
        var appCounts: [String: Int] = [:]
        
        for session in sessions where session.type == .work {
            for app in session.associatedApps {
                appCounts[app, default: 0] += 1
            }
        }
        
        return appCounts
    }
    
    func sessionsInRange(from startDate: Date, to endDate: Date) -> [WorkSession] {
        sessions.filter { session in
            session.startTime >= startDate && session.startTime <= endDate
        }
    }
}