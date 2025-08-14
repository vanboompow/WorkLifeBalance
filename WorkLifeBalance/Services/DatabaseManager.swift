//
//  DatabaseManager.swift
//  WorkLifeBalance
//

import Foundation
import SQLite

struct TimeEntry {
    let date: Date
    let workTime: TimeInterval
    let restTime: TimeInterval
    let idleTime: TimeInterval
}

class DatabaseManager {
    private var db: Connection?
    
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
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
            let appPath = "\(path)/WorkLifeBalance"
            
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(atPath: appPath, withIntermediateDirectories: true)
            
            // Connect to database
            db = try Connection("\(appPath)/worklifebalance.db")
            
            // Create tables
            createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    private func createTables() {
        do {
            try db?.run(timeEntries.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(date)
                t.column(state)
                t.column(workTime)
                t.column(restTime)
                t.column(idleTime)
                t.column(timestamp)
            })
        } catch {
            print("Create table error: \(error)")
        }
    }
    
    func saveTimeEntry(state: WorkState, workTime: TimeInterval, restTime: TimeInterval, idleTime: TimeInterval) {
        do {
            let insert = timeEntries.insert(
                self.date <- Date(),
                self.state <- state.description,
                self.workTime <- workTime,
                self.restTime <- restTime,
                self.idleTime <- idleTime,
                self.timestamp <- Date()
            )
            
            try db?.run(insert)
        } catch {
            print("Save error: \(error)")
        }
    }
    
    func getTodayData() -> TimeEntry? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        do {
            // Get the most recent entry for today to get accumulated totals
            let query = timeEntries
                .filter(date >= startOfDay)
                .order(timestamp.desc)
                .limit(1)
            
            if let entry = try db?.pluck(query) {
                // Return the accumulated totals from the most recent entry
                return TimeEntry(
                    date: entry[date],
                    workTime: entry[workTime],
                    restTime: entry[restTime],
                    idleTime: entry[idleTime]
                )
            }
        } catch {
            print("Query error: \(error)")
        }
        
        // Return zeros if no data for today
        return TimeEntry(date: Date(), workTime: 0, restTime: 0, idleTime: 0)
    }
    
    func getDataForDateRange(from: Date, to: Date) -> [TimeEntry] {
        var entries: [TimeEntry] = []
        
        do {
            let query = timeEntries
                .filter(date >= from && date <= to)
                .order(date.asc)
            
            if let results = try db?.prepare(query) {
                for row in results {
                    entries.append(TimeEntry(
                        date: row[date],
                        workTime: row[workTime],
                        restTime: row[restTime],
                        idleTime: row[idleTime]
                    ))
                }
            }
        } catch {
            print("Query error: \(error)")
        }
        
        return entries
    }
}
