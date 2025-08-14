//
//  DatabaseManager.swift
//  WorkLifeBalance
//

import Foundation
import SQLite
import OSLog

struct TimeEntry: Sendable {
    let date: Date
    let workTime: TimeInterval
    let restTime: TimeInterval
    let idleTime: TimeInterval
}

// MARK: - Database Errors
enum DatabaseError: Error, LocalizedError {
    case connectionFailed(String)
    case queryFailed(String)
    case invalidData(String)
    case backupFailed(String)
    case restoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Database connection failed: \(message)"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .backupFailed(let message):
            return "Backup failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        }
    }
}

@globalActor
actor DatabaseActor {
    static let shared = DatabaseActor()
    private init() {}
}

/// Thread-safe database manager using Swift concurrency
@DatabaseActor
final class DatabaseManager: Sendable {
    private var db: Connection?
    private let logger = Logger(subsystem: "WorkLifeBalance", category: "Database")
    
    // Table definitions
    private let timeEntries = Table("time_entries")
    private let id = Expression<Int64>("id")
    private let date = Expression<Date>("date")
    private let state = Expression<String>("state")
    private let workTime = Expression<Double>("work_time")
    private let restTime = Expression<Double>("rest_time")
    private let idleTime = Expression<Double>("idle_time")
    private let timestamp = Expression<Date>("timestamp")
    
    init() {
        Task {
            try? await setupDatabase()
        }
    }
    
    /// Initialize the database connection and create tables if needed
    static func create() async throws -> DatabaseManager {
        let manager = DatabaseManager()
        try await manager.setupDatabase()
        return manager
    }
    
    private func setupDatabase() async throws {
        let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        let appPath = "\(path)/WorkLifeBalance"
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(atPath: appPath, withIntermediateDirectories: true)
        
        // Connect to database
        db = try Connection("\(appPath)/worklifebalance.db")
        logger.info("Database connected successfully")
        
        // Create tables
        try await createTables()
    }
    
    private func createTables() async throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database connection not available")
        }
        
        do {
            try db.run(timeEntries.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(date)
                t.column(state)
                t.column(workTime)
                t.column(restTime)
                t.column(idleTime)
                t.column(timestamp)
            })
            logger.info("Database tables created successfully")
        } catch {
            logger.error("Create table error: \(error.localizedDescription)")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }
    
    func saveTimeEntry(state: WorkState, workTime: TimeInterval, restTime: TimeInterval, idleTime: TimeInterval) async throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database connection not available")
        }
        
        let insert = timeEntries.insert(
            self.date <- Date(),
            self.state <- state.description,
            self.workTime <- workTime,
            self.restTime <- restTime,
            self.idleTime <- idleTime,
            self.timestamp <- Date()
        )
        
        do {
            try db.run(insert)
            logger.debug("Time entry saved: \(state.description)")
        } catch {
            logger.error("Save error: \(error.localizedDescription)")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }
    
    func getTodayData() async throws -> TimeEntry? {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database connection not available")
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        do {
            // Get the most recent entry for today to get accumulated totals
            let query = timeEntries
                .filter(date >= startOfDay)
                .order(timestamp.desc)
                .limit(1)
            
            if let entry = try db.pluck(query) {
                // Return the accumulated totals from the most recent entry
                return TimeEntry(
                    date: entry[date],
                    workTime: entry[workTime],
                    restTime: entry[restTime],
                    idleTime: entry[idleTime]
                )
            }
        } catch {
            logger.error("Query error: \(error.localizedDescription)")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
        
        // Return zeros if no data for today
        return TimeEntry(date: Date(), workTime: 0, restTime: 0, idleTime: 0)
    }
    
    func getDataForDateRange(from: Date, to: Date) async throws -> [TimeEntry] {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database connection not available")
        }
        
        var entries: [TimeEntry] = []
        
        do {
            let query = timeEntries
                .filter(date >= from && date <= to)
                .order(date.asc)
            
            for row in try db.prepare(query) {
                entries.append(TimeEntry(
                    date: row[date],
                    workTime: row[workTime],
                    restTime: row[restTime],
                    idleTime: row[idleTime]
                ))
            }
        } catch {
            logger.error("Query error: \(error.localizedDescription)")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
        
        return entries
    }
    
    // MARK: - Export Support Methods
    
    /// Get daily aggregated statistics for export
    func getDailyStatistics(from startDate: Date, to endDate: Date) async throws -> [DayStatistics] {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database connection not available")
        }
        
        var statisticsDict: [String: DayStatistics] = [:]
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        do {
            let query = timeEntries
                .filter(date >= startDate && date <= endDate)
                .order(date.asc)
            
            for row in try db.prepare(query) {
                let entryDate = row[date]
                let dayStart = calendar.startOfDay(for: entryDate)
                let dateKey = dateFormatter.string(from: dayStart)
                
                if var existingStats = statisticsDict[dateKey] {
                    // Update with maximum values (accumulated totals)
                    existingStats.totalWorkTime = max(existingStats.totalWorkTime, row[workTime])
                    existingStats.totalRestTime = max(existingStats.totalRestTime, row[restTime])
                    existingStats.totalIdleTime = max(existingStats.totalIdleTime, row[idleTime])
                    statisticsDict[dateKey] = existingStats
                } else {
                    // Create new day statistics
                    let dayStats = DayStatistics(
                        date: dayStart,
                        totalWorkTime: row[workTime],
                        totalRestTime: row[restTime],
                        totalIdleTime: row[idleTime],
                        sessions: await generateSessionsForDay(dayStart, workTime: row[workTime], restTime: row[restTime], idleTime: row[idleTime]),
                        processActivities: await generateProcessActivitiesForDay(dayStart)
                    )
                    statisticsDict[dateKey] = dayStats
                }
            }
        } catch {
            logger.error("Query error getting daily statistics: \(error.localizedDescription)")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
        
        return Array(statisticsDict.values).sorted { $0.date < $1.date }
    }
    
    /// Get summary statistics for a date range
    func getSummaryStatistics(from startDate: Date, to endDate: Date) async throws -> (
        totalWorkTime: TimeInterval,
        totalRestTime: TimeInterval,
        totalIdleTime: TimeInterval,
        averageProductivity: Double,
        totalDays: Int
    ) {
        let dailyStats = try await getDailyStatistics(from: startDate, to: endDate)
        
        let totalWork = dailyStats.reduce(0) { $0 + $1.totalWorkTime }
        let totalRest = dailyStats.reduce(0) { $0 + $1.totalRestTime }
        let totalIdle = dailyStats.reduce(0) { $0 + $1.totalIdleTime }
        let avgProductivity = dailyStats.isEmpty ? 0 : 
            dailyStats.reduce(0) { $0 + $1.productivityPercentage } / Double(dailyStats.count)
        
        return (
            totalWorkTime: totalWork,
            totalRestTime: totalRest,
            totalIdleTime: totalIdle,
            averageProductivity: avgProductivity,
            totalDays: dailyStats.count
        )
    }
    
    /// Get the most productive day in a date range
    func getMostProductiveDay(from startDate: Date, to endDate: Date) async throws -> DayStatistics? {
        let dailyStats = try await getDailyStatistics(from: startDate, to: endDate)
        return dailyStats.max { $0.productivityPercentage < $1.productivityPercentage }
    }
    
    /// Get productivity trend data for charting
    func getProductivityTrend(from startDate: Date, to endDate: Date) async throws -> [(date: Date, productivity: Double)] {
        let dailyStats = try await getDailyStatistics(from: startDate, to: endDate)
        return dailyStats.map { (date: $0.date, productivity: $0.productivityPercentage) }
    }
    
    /// Check if database has any data for the given date range
    func hasDataInRange(from startDate: Date, to endDate: Date) async throws -> Bool {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database connection not available")
        }
        
        do {
            let query = timeEntries
                .filter(date >= startDate && date <= endDate)
                .limit(1)
            
            return try db.pluck(query) != nil
        } catch {
            logger.error("Error checking data existence: \(error.localizedDescription)")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }
    
    /// Get database statistics for export metadata
    func getDatabaseInfo() async throws -> (totalEntries: Int, oldestEntry: Date?, newestEntry: Date?, databaseSize: Int64) {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database connection not available")
        }
        
        var totalEntries = 0
        var oldestEntry: Date?
        var newestEntry: Date?
        var databaseSize: Int64 = 0
        
        do {
            // Count total entries
            totalEntries = try db.scalar(timeEntries.count)
            
            // Get oldest entry
            if let oldest = try db.pluck(timeEntries.order(date.asc).limit(1)) {
                oldestEntry = oldest[date]
            }
            
            // Get newest entry
            if let newest = try db.pluck(timeEntries.order(date.desc).limit(1)) {
                newestEntry = newest[date]
            }
            
            // Get database file size
            let dbPath = db.description
            let url = URL(fileURLWithPath: dbPath)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                databaseSize = attributes[.size] as? Int64 ?? 0
            }
        } catch {
            logger.error("Error getting database info: \(error.localizedDescription)")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
        
        return (
            totalEntries: totalEntries,
            oldestEntry: oldestEntry,
            newestEntry: newestEntry,
            databaseSize: databaseSize
        )
    }
    
    // MARK: - Private Helper Methods for Export
    
    /// Generate estimated work sessions based on accumulated time data
    private func generateSessionsForDay(_ date: Date, workTime: TimeInterval, restTime: TimeInterval, idleTime: TimeInterval) async -> [WorkSession] {
        var sessions: [WorkSession] = []
        let calendar = Calendar.current
        let currentTime = calendar.startOfDay(for: date)
        
        // This is a simplified approach since we don't store actual session data
        // In a real implementation, you would store session start/end times in the database
        
        if workTime > 0 {
            // Create estimated work sessions
            let avgSessionLength: TimeInterval = 3600 // 1 hour average
            let sessionCount = max(1, Int(workTime / avgSessionLength))
            let sessionDuration = workTime / Double(sessionCount)
            
            for i in 0..<sessionCount {
                let startTime = calendar.date(byAdding: .hour, value: i * 2, to: currentTime) ?? currentTime
                let endTime = calendar.date(byAdding: .second, value: Int(sessionDuration), to: startTime) ?? startTime
                
                let session = WorkSession(
                    type: .work,
                    startTime: startTime,
                    endTime: endTime,
                    associatedApps: ["Estimated Session"]
                )
                sessions.append(session)
            }
        }
        
        if restTime > 0 {
            // Create estimated rest sessions
            let restSession = WorkSession(
                type: .rest,
                startTime: calendar.date(byAdding: .hour, value: 4, to: currentTime) ?? currentTime,
                endTime: calendar.date(byAdding: .second, value: Int(restTime), to: currentTime) ?? currentTime,
                associatedApps: []
            )
            sessions.append(restSession)
        }
        
        return sessions.sorted { $0.startTime < $1.startTime }
    }
    
    /// Generate estimated process activities for a day
    private func generateProcessActivitiesForDay(_ date: Date) async -> [ProcessActivity] {
        // This is a placeholder implementation
        // In a real app, you would store actual process activity data
        return []
    }
    
    /// Backup database to a specified location
    func backupDatabase(to url: URL) async throws {
        guard let dbPath = db?.description else {
            throw DatabaseError.backupFailed("Database path not available")
        }
        
        let sourceURL = URL(fileURLWithPath: dbPath)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: url)
            logger.info("Database backed up to: \(url.path)")
        } catch {
            logger.error("Backup failed: \(error.localizedDescription)")
            throw DatabaseError.backupFailed(error.localizedDescription)
        }
    }
    
    /// Restore database from a backup
    func restoreDatabase(from url: URL) async throws {
        guard let dbPath = db?.description else {
            throw DatabaseError.restoreFailed("Database path not available")
        }
        
        let destinationURL = URL(fileURLWithPath: dbPath)
        
        // Close current connection
        db = nil
        
        do {
            // Replace database file
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Reconnect
            try await setupDatabase()
            logger.info("Database restored from: \(url.path)")
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            throw DatabaseError.restoreFailed(error.localizedDescription)
        }
    }
}
