//
//  ExportManager.swift
//  WorkLifeBalance
//
//  Core export functionality for various data formats
//

import Foundation
import AppKit
import SQLite
import UniformTypeIdentifiers

// MARK: - Export Error Types
enum ExportError: LocalizedError {
    case noDataFound
    case invalidDateRange
    case unsupportedFormat
    case fileCreationFailed
    case permissionDenied
    case diskSpaceInsufficient
    case dataCorrupted
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .noDataFound:
            return "No data found for the selected date range."
        case .invalidDateRange:
            return "Invalid date range selected."
        case .unsupportedFormat:
            return "The selected export format is not supported."
        case .fileCreationFailed:
            return "Failed to create the export file."
        case .permissionDenied:
            return "Permission denied. Please check file access permissions."
        case .diskSpaceInsufficient:
            return "Insufficient disk space to create the export file."
        case .dataCorrupted:
            return "Data appears to be corrupted and cannot be exported."
        case .unknownError(let message):
            return "Export failed: \(message)"
        }
    }
}

// MARK: - Export Data Types
struct ExportData {
    let dateRange: DateInterval
    let dayStatistics: [DayStatistics]
    let timeEntries: [TimeEntry]
    let userPreferences: UserPreferences?
    let metadata: ExportMetadata
}

struct ExportMetadata {
    let exportDate: Date
    let appVersion: String
    let totalDays: Int
    let totalSessions: Int
    let dataVersion: String
    
    init() {
        self.exportDate = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.totalDays = 0
        self.totalSessions = 0
        self.dataVersion = "1.0"
    }
    
    init(dayStatistics: [DayStatistics], timeEntries: [TimeEntry]) {
        self.exportDate = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.totalDays = dayStatistics.count
        self.totalSessions = dayStatistics.reduce(0) { $0 + $1.sessions.count }
        self.dataVersion = "1.0"
    }
}

// MARK: - Export Manager
@MainActor
class ExportManager: ObservableObject {
    static let shared = ExportManager()
    
    private let databaseManager = DatabaseManager()
    private let reportGenerator = ReportGenerator()
    private let fileManager = FileManager.default
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    
    private init() {}
    
    // MARK: - Main Export Function
    func exportData(
        configuration: ExportConfiguration,
        progressHandler: @escaping (Double) async -> Void
    ) async throws -> URL {
        isExporting = true
        exportProgress = 0.0
        
        defer {
            isExporting = false
            exportProgress = 0.0
        }
        
        do {
            // Validate configuration
            try validateConfiguration(configuration)
            await progressHandler(0.1)
            
            // Retrieve data from database
            let exportData = try await retrieveExportData(configuration: configuration)
            await progressHandler(0.3)
            
            // Generate filename
            let filename = generateFilename(configuration: configuration)
            
            // Create export file based on format
            let url: URL
            switch configuration.format {
            case .csv:
                url = try await exportToCSV(data: exportData, configuration: configuration, filename: filename)
            case .json:
                url = try await exportToJSON(data: exportData, configuration: configuration, filename: filename)
            case .pdf:
                url = try await exportToPDF(data: exportData, configuration: configuration, filename: filename)
            case .html:
                url = try await exportToHTML(data: exportData, configuration: configuration, filename: filename)
            case .excel:
                url = try await exportToExcel(data: exportData, configuration: configuration, filename: filename)
            }
            
            await progressHandler(1.0)
            return url
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Data Retrieval
    private func retrieveExportData(configuration: ExportConfiguration) async throws -> ExportData {
        let startDate = configuration.effectiveStartDate
        let endDate = configuration.effectiveEndDate
        
        // Check if database has data for the range
        guard databaseManager.hasDataInRange(from: startDate, to: endDate) else {
            throw ExportError.noDataFound
        }
        
        // Get time entries from database (legacy format)
        let timeEntries = databaseManager.getDataForDateRange(from: startDate, to: endDate)
        
        // Get daily statistics (new format) - this will use the extended DatabaseManager methods
        let dayStatistics = databaseManager.getDailyStatistics(from: startDate, to: endDate)
        
        // Get user preferences if requested
        let userPreferences = configuration.includeSettings ? PreferencesManager.shared.preferences : nil
        
        // Create metadata
        let metadata = ExportMetadata(dayStatistics: dayStatistics, timeEntries: timeEntries)
        
        return ExportData(
            dateRange: DateInterval(start: startDate, end: endDate),
            dayStatistics: dayStatistics,
            timeEntries: timeEntries,
            userPreferences: userPreferences,
            metadata: metadata
        )
    }
    
    // MARK: - CSV Export
    private func exportToCSV(
        data: ExportData, 
        configuration: ExportConfiguration, 
        filename: String
    ) async throws -> URL {
        var csvContent = ""
        
        // Add header
        if configuration.includeStatistics {
            csvContent += "Date,Work Time (seconds),Rest Time (seconds),Idle Time (seconds),Total Time (seconds),Productivity %,Sessions Count\n"
            
            for dayStats in data.dayStatistics {
                let dateStr = formatDateForCSV(dayStats.date)
                let productivity = String(format: "%.2f", dayStats.productivityPercentage)
                let line = "\(dateStr),\(dayStats.totalWorkTime),\(dayStats.totalRestTime),\(dayStats.totalIdleTime),\(dayStats.totalTime),\(productivity),\(dayStats.sessions.count)\n"
                csvContent += line
            }
        }
        
        if configuration.includeWorkSessions {
            csvContent += "\n\nWork Sessions\n"
            csvContent += "Date,Session Type,Start Time,End Time,Duration (seconds),Associated Apps,Notes\n"
            
            for dayStats in data.dayStatistics {
                for session in dayStats.sessions {
                    let dateStr = formatDateForCSV(dayStats.date)
                    let startTime = formatTimeForCSV(session.startTime)
                    let endTime = session.endTime != nil ? formatTimeForCSV(session.endTime!) : "Ongoing"
                    let apps = session.associatedApps.joined(separator: "; ")
                    let notes = session.notes?.replacingOccurrences(of: "\n", with: " ") ?? ""
                    let line = "\(dateStr),\(session.type.displayName),\(startTime),\(endTime),\(session.duration),\"\(apps)\",\"\(notes)\"\n"
                    csvContent += line
                }
            }
        }
        
        if configuration.includeProcessActivity {
            csvContent += "\n\nProcess Activity\n"
            csvContent += "Date,Application Name,Process Name,Bundle ID,Total Active Time (seconds),Activation Count,Average Session Time (seconds)\n"
            
            for dayStats in data.dayStatistics {
                for activity in dayStats.processActivities {
                    let dateStr = formatDateForCSV(dayStats.date)
                    let appName = configuration.privacyMode ? "***" : activity.applicationName
                    let processName = configuration.privacyMode ? "***" : activity.processName
                    let bundleId = configuration.privacyMode ? "***" : (activity.bundleIdentifier ?? "")
                    let line = "\(dateStr),\"\(appName)\",\"\(processName)\",\"\(bundleId)\",\(activity.totalActiveTime),\(activity.activationCount),\(activity.averageSessionTime)\n"
                    csvContent += line
                }
            }
        }
        
        return try await saveToFile(content: csvContent, filename: filename, extension: "csv")
    }
    
    // MARK: - JSON Export
    private func exportToJSON(
        data: ExportData, 
        configuration: ExportConfiguration, 
        filename: String
    ) async throws -> URL {
        var jsonData: [String: Any] = [:]
        
        // Add metadata
        jsonData["metadata"] = [
            "exportDate": ISO8601DateFormatter().string(from: data.metadata.exportDate),
            "appVersion": data.metadata.appVersion,
            "dataVersion": data.metadata.dataVersion,
            "dateRange": [
                "start": ISO8601DateFormatter().string(from: data.dateRange.start),
                "end": ISO8601DateFormatter().string(from: data.dateRange.end)
            ],
            "configuration": [
                "format": configuration.format.rawValue,
                "includeWorkSessions": configuration.includeWorkSessions,
                "includeProcessActivity": configuration.includeProcessActivity,
                "includeStatistics": configuration.includeStatistics,
                "privacyMode": configuration.privacyMode
            ]
        ]
        
        // Add day statistics
        if configuration.includeStatistics {
            let dayStatsData = data.dayStatistics.map { dayStats in
                var statsDict: [String: Any] = [
                    "date": ISO8601DateFormatter().string(from: dayStats.date),
                    "totalWorkTime": dayStats.totalWorkTime,
                    "totalRestTime": dayStats.totalRestTime,
                    "totalIdleTime": dayStats.totalIdleTime,
                    "totalTime": dayStats.totalTime,
                    "productivityPercentage": dayStats.productivityPercentage,
                    "numberOfBreaks": dayStats.numberOfBreaks
                ]
                
                if let longestSession = dayStats.longestWorkSession {
                    statsDict["longestWorkSession"] = [
                        "duration": longestSession.duration,
                        "startTime": ISO8601DateFormatter().string(from: longestSession.startTime)
                    ]
                }
                
                return statsDict
            }
            jsonData["dayStatistics"] = dayStatsData
        }
        
        // Add work sessions
        if configuration.includeWorkSessions {
            var sessionsData: [[String: Any]] = []
            
            for dayStats in data.dayStatistics {
                for session in dayStats.sessions {
                    var sessionDict: [String: Any] = [
                        "id": session.id.uuidString,
                        "type": session.type.rawValue,
                        "startTime": ISO8601DateFormatter().string(from: session.startTime),
                        "duration": session.duration,
                        "isActive": session.isActive
                    ]
                    
                    if let endTime = session.endTime {
                        sessionDict["endTime"] = ISO8601DateFormatter().string(from: endTime)
                    }
                    
                    if let notes = session.notes {
                        sessionDict["notes"] = notes
                    }
                    
                    sessionDict["associatedApps"] = configuration.privacyMode ? ["***"] : session.associatedApps
                    
                    sessionsData.append(sessionDict)
                }
            }
            jsonData["workSessions"] = sessionsData
        }
        
        // Add process activity
        if configuration.includeProcessActivity {
            var processData: [[String: Any]] = []
            
            for dayStats in data.dayStatistics {
                for activity in dayStats.processActivities {
                    let activityDict: [String: Any] = [
                        "id": activity.id.uuidString,
                        "applicationName": configuration.privacyMode ? "***" : activity.applicationName,
                        "processName": configuration.privacyMode ? "***" : activity.processName,
                        "bundleIdentifier": configuration.privacyMode ? "***" : (activity.bundleIdentifier ?? ""),
                        "totalActiveTime": activity.totalActiveTime,
                        "activationCount": activity.activationCount,
                        "averageSessionTime": activity.averageSessionTime,
                        "firstSeen": ISO8601DateFormatter().string(from: activity.firstSeen),
                        "lastActiveTime": ISO8601DateFormatter().string(from: activity.lastActiveTime)
                    ]
                    processData.append(activityDict)
                }
            }
            jsonData["processActivity"] = processData
        }
        
        // Add user preferences
        if configuration.includeSettings, let preferences = data.userPreferences {
            if let preferencesData = try? JSONEncoder().encode(preferences),
               let preferencesDict = try? JSONSerialization.jsonObject(with: preferencesData) {
                jsonData["userPreferences"] = preferencesDict
            }
        }
        
        let jsonFileData = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
        let jsonString = String(data: jsonFileData, encoding: .utf8) ?? ""
        
        return try await saveToFile(content: jsonString, filename: filename, extension: "json")
    }
    
    // MARK: - PDF Export
    private func exportToPDF(
        data: ExportData, 
        configuration: ExportConfiguration, 
        filename: String
    ) async throws -> URL {
        return try await reportGenerator.generateReport(
            data: data, 
            configuration: configuration, 
            filename: filename
        )
    }
    
    // MARK: - HTML Export
    private func exportToHTML(
        data: ExportData, 
        configuration: ExportConfiguration, 
        filename: String
    ) async throws -> URL {
        let htmlContent = generateHTMLContent(data: data, configuration: configuration)
        return try await saveToFile(content: htmlContent, filename: filename, extension: "html")
    }
    
    // MARK: - Excel Export (Simplified CSV for now)
    private func exportToExcel(
        data: ExportData, 
        configuration: ExportConfiguration, 
        filename: String
    ) async throws -> URL {
        // For now, export as CSV with .xlsx extension
        // A full Excel implementation would require additional dependencies
        let csvContent = try await exportToCSV(data: data, configuration: configuration, filename: filename)
        
        // Copy CSV to Excel filename
        let excelURL = csvContent.deletingLastPathComponent().appendingPathComponent(filename).appendingPathExtension("xlsx")
        try fileManager.copyItem(at: csvContent, to: excelURL)
        try fileManager.removeItem(at: csvContent)
        
        return excelURL
    }
    
    // MARK: - Helper Methods
    private func validateConfiguration(_ configuration: ExportConfiguration) throws {
        if configuration.effectiveStartDate > configuration.effectiveEndDate {
            throw ExportError.invalidDateRange
        }
        
        if !configuration.includeWorkSessions && 
           !configuration.includeProcessActivity && 
           !configuration.includeStatistics {
            throw ExportError.noDataFound
        }
    }
    
    private func generateFilename(configuration: ExportConfiguration) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        let timeString = timeFormatter.string(from: Date())
        
        return configuration.fileNamingPattern
            .replacingOccurrences(of: "{date}", with: dateString)
            .replacingOccurrences(of: "{time}", with: timeString)
            .replacingOccurrences(of: "{format}", with: configuration.format.rawValue.uppercased())
    }
    
    private func saveToFile(content: String, filename: String, extension: String) async throws -> URL {
        let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopURL.appendingPathComponent(filename).appendingPathExtension(`extension`)
        
        // Check if file exists and create unique name if needed
        let finalURL = generateUniqueFileURL(baseURL: fileURL)
        
        try content.write(to: finalURL, atomically: true, encoding: .utf8)
        return finalURL
    }
    
    private func generateUniqueFileURL(baseURL: URL) -> URL {
        var url = baseURL
        var counter = 1
        
        while fileManager.fileExists(atPath: url.path) {
            let nameWithoutExtension = baseURL.deletingPathExtension().lastPathComponent
            let pathExtension = baseURL.pathExtension
            let newName = "\(nameWithoutExtension)_\(counter)"
            url = baseURL.deletingLastPathComponent()
                .appendingPathComponent(newName)
                .appendingPathExtension(pathExtension)
            counter += 1
        }
        
        return url
    }
    
    private func formatDateForCSV(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatTimeForCSV(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func generateHTMLContent(data: ExportData, configuration: ExportConfiguration) -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Work Life Balance Report</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; }
                .header { border-bottom: 2px solid #007AFF; padding-bottom: 20px; margin-bottom: 30px; }
                .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
                .stat-card { background: #f5f5f5; padding: 20px; border-radius: 8px; }
                .stat-value { font-size: 24px; font-weight: bold; color: #007AFF; }
                .stat-label { font-size: 14px; color: #666; }
                table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
                th { background: #f8f9fa; font-weight: 600; }
                .productivity-high { color: #28a745; }
                .productivity-medium { color: #ffc107; }
                .productivity-low { color: #dc3545; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Work Life Balance Report</h1>
                <p>Generated on \(formatDateForHTML(Date()))</p>
                <p>Period: \(formatDateForHTML(data.dateRange.start)) to \(formatDateForHTML(data.dateRange.end))</p>
            </div>
        """
        
        if configuration.includeStatistics {
            let totalWorkTime = data.dayStatistics.reduce(0) { $0 + $1.totalWorkTime }
            let totalRestTime = data.dayStatistics.reduce(0) { $0 + $1.totalRestTime }
            let averageProductivity = data.dayStatistics.reduce(0) { $0 + $1.productivityPercentage } / Double(max(1, data.dayStatistics.count))
            
            html += """
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-value">\(formatDurationForHTML(totalWorkTime))</div>
                    <div class="stat-label">Total Work Time</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">\(formatDurationForHTML(totalRestTime))</div>
                    <div class="stat-label">Total Rest Time</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">\(String(format: "%.1f%%", averageProductivity))</div>
                    <div class="stat-label">Average Productivity</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">\(data.dayStatistics.count)</div>
                    <div class="stat-label">Days Tracked</div>
                </div>
            </div>
            
            <h2>Daily Statistics</h2>
            <table>
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Work Time</th>
                        <th>Rest Time</th>
                        <th>Productivity</th>
                        <th>Sessions</th>
                    </tr>
                </thead>
                <tbody>
            """
            
            for dayStats in data.dayStatistics {
                let productivityClass = dayStats.productivityPercentage >= 70 ? "productivity-high" :
                                       dayStats.productivityPercentage >= 40 ? "productivity-medium" : "productivity-low"
                
                html += """
                    <tr>
                        <td>\(formatDateForHTML(dayStats.date))</td>
                        <td>\(formatDurationForHTML(dayStats.totalWorkTime))</td>
                        <td>\(formatDurationForHTML(dayStats.totalRestTime))</td>
                        <td class="\(productivityClass)">\(String(format: "%.1f%%", dayStats.productivityPercentage))</td>
                        <td>\(dayStats.sessions.count)</td>
                    </tr>
                """
            }
            
            html += """
                </tbody>
            </table>
            """
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    private func formatDateForHTML(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDurationForHTML(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}