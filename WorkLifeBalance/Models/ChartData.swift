//
//  ChartData.swift
//  WorkLifeBalance
//
//  Data models for chart visualization
//

import Foundation
import SwiftUI
import Charts

// MARK: - ChartDataPoint
/// Generic data point for charts
struct ChartDataPoint: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let value: Double
    let category: String?
    let date: Date?
    let color: Color?
    
    init(label: String, value: Double, category: String? = nil, date: Date? = nil, color: Color? = nil) {
        self.label = label
        self.value = value
        self.category = category
        self.date = date
        self.color = color
    }
}

// MARK: - TimeChartData
/// Data structure for time-based charts
struct TimeChartData: Identifiable {
    let id = UUID()
    let date: Date
    let workTime: TimeInterval
    let restTime: TimeInterval
    let idleTime: TimeInterval
    
    var totalTime: TimeInterval {
        workTime + restTime + idleTime
    }
    
    var productivityPercentage: Double {
        guard totalTime > 0 else { return 0 }
        return (workTime / totalTime) * 100
    }
    
    // Convert to chart data points for stacked bar charts
    var stackedDataPoints: [ChartDataPoint] {
        [
            ChartDataPoint(label: "Work", value: workTime, category: "work", date: date, color: .green),
            ChartDataPoint(label: "Rest", value: restTime, category: "rest", date: date, color: .blue),
            ChartDataPoint(label: "Idle", value: idleTime, category: "idle", date: date, color: .gray)
        ]
    }
    
    // Convert to chart data points for pie charts
    var pieDataPoints: [ChartDataPoint] {
        var points: [ChartDataPoint] = []
        
        if workTime > 0 {
            points.append(ChartDataPoint(
                label: "Work",
                value: workTime,
                category: "work",
                color: .green
            ))
        }
        
        if restTime > 0 {
            points.append(ChartDataPoint(
                label: "Rest",
                value: restTime,
                category: "rest",
                color: .blue
            ))
        }
        
        if idleTime > 0 {
            points.append(ChartDataPoint(
                label: "Idle",
                value: idleTime,
                category: "idle",
                color: .gray
            ))
        }
        
        return points
    }
}

// MARK: - ProductivityChartData
/// Data structure for productivity trend charts
struct ProductivityChartData: Identifiable {
    let id = UUID()
    let period: String
    let date: Date
    let productivityScore: Double
    let averageProductivity: Double
    let targetProductivity: Double
    
    var isAboveAverage: Bool {
        productivityScore >= averageProductivity
    }
    
    var isAboveTarget: Bool {
        productivityScore >= targetProductivity
    }
    
    var trend: ProductivityTrend {
        if productivityScore >= targetProductivity {
            return .excellent
        } else if productivityScore >= averageProductivity {
            return .good
        } else if productivityScore >= averageProductivity * 0.8 {
            return .fair
        } else {
            return .needsImprovement
        }
    }
}

enum ProductivityTrend {
    case excellent
    case good
    case fair
    case needsImprovement
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .needsImprovement: return .red
        }
    }
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .needsImprovement: return "Needs Improvement"
        }
    }
}

// MARK: - ApplicationChartData
/// Data structure for application usage charts
struct ApplicationChartData: Identifiable {
    let id = UUID()
    let applicationName: String
    let totalTime: TimeInterval
    let percentage: Double
    let icon: NSImage?
    let isWorkRelated: Bool
    
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalTime) ?? "0m"
    }
    
    var color: Color {
        isWorkRelated ? .green : .orange
    }
}

// MARK: - ChartDataAggregator
/// Utility class for aggregating chart data
class ChartDataAggregator {
    
    // Create time series data from day statistics
    static func createTimeSeriesData(from statistics: [DayStatistics]) -> [TimeChartData] {
        statistics.map { stat in
            TimeChartData(
                date: stat.date,
                workTime: stat.totalWorkTime,
                restTime: stat.totalRestTime,
                idleTime: stat.totalIdleTime
            )
        }.sorted { $0.date < $1.date }
    }
    
    // Create productivity trend data
    static func createProductivityTrendData(from statistics: [DayStatistics],
                                           targetProductivity: Double = 70.0) -> [ProductivityChartData] {
        let averageProductivity = statistics.isEmpty ? 0 :
            statistics.map { $0.productivityPercentage }.reduce(0, +) / Double(statistics.count)
        
        return statistics.map { stat in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            
            return ProductivityChartData(
                period: formatter.string(from: stat.date),
                date: stat.date,
                productivityScore: stat.productivityPercentage,
                averageProductivity: averageProductivity,
                targetProductivity: targetProductivity
            )
        }.sorted { $0.date < $1.date }
    }
    
    // Create application usage data
    static func createApplicationUsageData(from activities: [ProcessActivity],
                                          workingApps: [String]) -> [ApplicationChartData] {
        let totalTime = activities.reduce(0) { $0 + $1.totalActiveTime }
        
        return activities
            .sorted { $0.totalActiveTime > $1.totalActiveTime }
            .prefix(10) // Top 10 apps
            .map { activity in
                ApplicationChartData(
                    applicationName: activity.applicationName,
                    totalTime: activity.totalActiveTime,
                    percentage: totalTime > 0 ? (activity.totalActiveTime / totalTime) * 100 : 0,
                    icon: activity.icon,
                    isWorkRelated: activity.isWorkRelated(workingApps: workingApps)
                )
            }
    }
    
    // Create hourly distribution data
    static func createHourlyDistributionData(from sessions: [WorkSession]) -> [ChartDataPoint] {
        var hourlyData: [Int: TimeInterval] = [:]
        
        for session in sessions where session.type == .work {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: session.startTime)
            hourlyData[hour, default: 0] += session.duration
        }
        
        return (0..<24).map { hour in
            ChartDataPoint(
                label: String(format: "%02d:00", hour),
                value: hourlyData[hour] ?? 0,
                category: "hourly"
            )
        }
    }
}