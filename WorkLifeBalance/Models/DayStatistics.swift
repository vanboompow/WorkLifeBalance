//
//  DayStatistics.swift
//  WorkLifeBalance
//
//  Data model for tracking daily work/rest/idle statistics
//

import Foundation

// MARK: - DayStatistics
/// Represents statistics for a single day of activity tracking
struct DayStatistics: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    var totalWorkTime: TimeInterval
    var totalRestTime: TimeInterval
    var totalIdleTime: TimeInterval
    var sessions: [WorkSession]
    var processActivities: [ProcessActivity]
    
    // Computed properties
    var totalTime: TimeInterval {
        totalWorkTime + totalRestTime + totalIdleTime
    }
    
    var productivityPercentage: Double {
        guard totalTime > 0 else { return 0 }
        return (totalWorkTime / totalTime) * 100
    }
    
    var effectiveWorkTime: TimeInterval {
        totalWorkTime - (totalIdleTime * 0.5) // Adjust for brief idle periods during work
    }
    
    var averageSessionLength: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        let workSessions = sessions.filter { $0.type == .work }
        guard !workSessions.isEmpty else { return 0 }
        return workSessions.reduce(0) { $0 + $1.duration } / Double(workSessions.count)
    }
    
    var longestWorkSession: WorkSession? {
        sessions.filter { $0.type == .work }.max(by: { $0.duration < $1.duration })
    }
    
    var numberOfBreaks: Int {
        sessions.filter { $0.type == .rest }.count
    }
    
    // Initializers
    init(id: UUID = UUID(),
         date: Date = Date(),
         totalWorkTime: TimeInterval = 0,
         totalRestTime: TimeInterval = 0,
         totalIdleTime: TimeInterval = 0,
         sessions: [WorkSession] = [],
         processActivities: [ProcessActivity] = []) {
        self.id = id
        self.date = date
        self.totalWorkTime = totalWorkTime
        self.totalRestTime = totalRestTime
        self.totalIdleTime = totalIdleTime
        self.sessions = sessions
        self.processActivities = processActivities
    }
    
    // Helper methods
    mutating func addSession(_ session: WorkSession) {
        sessions.append(session)
        
        switch session.type {
        case .work:
            totalWorkTime += session.duration
        case .rest:
            totalRestTime += session.duration
        case .idle:
            totalIdleTime += session.duration
        }
    }
    
    mutating func updateCurrentSession(additionalTime: TimeInterval, type: SessionType) {
        switch type {
        case .work:
            totalWorkTime += additionalTime
        case .rest:
            totalRestTime += additionalTime
        case .idle:
            totalIdleTime += additionalTime
        }
    }
    
    func summary() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        
        let work = formatter.string(from: totalWorkTime) ?? "0m"
        let rest = formatter.string(from: totalRestTime) ?? "0m"
        let idle = formatter.string(from: totalIdleTime) ?? "0m"
        
        return "Work: \(work), Rest: \(rest), Idle: \(idle) | Productivity: \(String(format: "%.1f%%", productivityPercentage))"
    }
}

// MARK: - Extensions for Formatting
extension DayStatistics {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }
    
    var isThisWeek: Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}