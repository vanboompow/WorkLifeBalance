//
//  TimeTrackable.swift
//  WorkLifeBalance
//
//  Protocol definitions for time tracking functionality
//

import Foundation
import Combine

// MARK: - TimeTrackable Protocol
/// Protocol for objects that can track time
protocol TimeTrackable: AnyObject {
    var workTime: TimeInterval { get set }
    var restTime: TimeInterval { get set }
    var idleTime: TimeInterval { get set }
    var currentState: WorkState { get }
    
    func startTracking()
    func stopTracking()
    func pauseTracking()
    func resumeTracking()
    func resetTracking()
    
    func formattedTime(for interval: TimeInterval) -> String
}

// MARK: - Default Implementation
extension TimeTrackable {
    func formattedTime(for interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? "00:00:00"
    }
    
    var totalTrackedTime: TimeInterval {
        workTime + restTime + idleTime
    }
    
    var productivityScore: Double {
        guard totalTrackedTime > 0 else { return 0 }
        return (workTime / totalTrackedTime) * 100
    }
}

// MARK: - TimeTrackingDelegate Protocol
/// Protocol for objects that respond to time tracking events
protocol TimeTrackingDelegate: AnyObject {
    func timeTracker(_ tracker: TimeTrackable, didChangeStateTo state: WorkState)
    func timeTracker(_ tracker: TimeTrackable, didUpdateTime time: TimeInterval, for state: WorkState)
    func timeTrackerDidStartTracking(_ tracker: TimeTrackable)
    func timeTrackerDidStopTracking(_ tracker: TimeTrackable)
    func timeTrackerDidPauseTracking(_ tracker: TimeTrackable)
    func timeTrackerDidResumeTracking(_ tracker: TimeTrackable)
}

// MARK: - Optional Default Implementation
extension TimeTrackingDelegate {
    func timeTrackerDidStartTracking(_ tracker: TimeTrackable) {}
    func timeTrackerDidStopTracking(_ tracker: TimeTrackable) {}
    func timeTrackerDidPauseTracking(_ tracker: TimeTrackable) {}
    func timeTrackerDidResumeTracking(_ tracker: TimeTrackable) {}
}

// MARK: - TimeTrackingObservable Protocol
/// Protocol for observable time tracking with Combine
protocol TimeTrackingObservable: TimeTrackable, ObservableObject {
    var statePublisher: Published<WorkState>.Publisher { get }
    var workTimePublisher: Published<TimeInterval>.Publisher { get }
    var restTimePublisher: Published<TimeInterval>.Publisher { get }
    var idleTimePublisher: Published<TimeInterval>.Publisher { get }
}

// MARK: - SessionTrackable Protocol
/// Protocol for objects that track sessions
protocol SessionTrackable {
    var currentSession: WorkSession? { get }
    var sessions: [WorkSession] { get }
    
    func startNewSession(type: SessionType)
    func endCurrentSession()
    func getSessionsForDate(_ date: Date) -> [WorkSession]
    func getSessionsInRange(from: Date, to: Date) -> [WorkSession]
}

// MARK: - ActivityTrackable Protocol
/// Protocol for objects that track application activity
protocol ActivityTrackable {
    var processActivities: [ProcessActivity] { get }
    var currentActiveProcess: ProcessActivity? { get }
    
    func recordProcessActivity(_ activity: ProcessActivity)
    func getTopProcesses(limit: Int) -> [ProcessActivity]
    func getTotalTimeForProcess(_ processName: String) -> TimeInterval
}

// MARK: - StatisticsProvider Protocol
/// Protocol for objects that provide statistics
protocol StatisticsProvider {
    func getDayStatistics(for date: Date) -> DayStatistics?
    func getWeekStatistics(for date: Date) -> [DayStatistics]
    func getMonthStatistics(for date: Date) -> [DayStatistics]
    func getAverageProductivity(over days: Int) -> Double
    func getTotalTime(for type: SessionType, over days: Int) -> TimeInterval
}

// MARK: - PersistenceProvider Protocol
/// Protocol for objects that handle data persistence
protocol PersistenceProvider {
    func save(_ statistics: DayStatistics) throws
    func load(for date: Date) throws -> DayStatistics?
    func loadRange(from: Date, to: Date) throws -> [DayStatistics]
    func deleteStatistics(for date: Date) throws
    func exportData(from: Date, to: Date) throws -> Data
}