//
//  ReportGenerator.swift
//  WorkLifeBalance
//
//  PDF report generation with charts and professional formatting
//

import Foundation
import AppKit
import PDFKit
import CoreGraphics
import Charts
import SwiftUI

// MARK: - Report Generator
class ReportGenerator {
    
    // MARK: - Constants
    private let pageSize = CGSize(width: 612, height: 792) // US Letter size
    private let margin: CGFloat = 72 // 1 inch margin
    private let lineHeight: CGFloat = 20
    private let headerHeight: CGFloat = 80
    private let footerHeight: CGFloat = 40
    
    private var currentPageY: CGFloat = 0
    private var pageNumber: Int = 1
    private var pdfContext: CGContext?
    
    // MARK: - Public Methods
    func generateReport(
        data: ExportData,
        configuration: ExportConfiguration,
        filename: String
    ) async throws -> URL {
        
        let documentsURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename).appendingPathExtension("pdf")
        
        // Create PDF context
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let pdfContext = CGContext(url: fileURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw ExportError.fileCreationFailed
        }
        
        self.pdfContext = pdfContext
        currentPageY = margin
        pageNumber = 1
        
        // Start creating the PDF
        pdfContext.beginPDFPage(nil)
        
        // Generate report content
        await generateReportContent(data: data, configuration: configuration)
        
        // End the PDF
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        return fileURL
    }
    
    // MARK: - Report Content Generation
    private func generateReportContent(data: ExportData, configuration: ExportConfiguration) async {
        guard let context = pdfContext else { return }
        
        // Draw header
        drawReportHeader(data: data, configuration: configuration, context: context)
        
        // Draw executive summary
        drawExecutiveSummary(data: data, context: context)
        
        // Draw charts if enabled
        if configuration.includeCharts {
            await drawCharts(data: data, context: context)
        }
        
        // Draw detailed statistics
        if configuration.includeStatistics {
            drawDetailedStatistics(data: data, context: context)
        }
        
        // Draw work sessions
        if configuration.includeWorkSessions {
            drawWorkSessions(data: data, configuration: configuration, context: context)
        }
        
        // Draw process activity
        if configuration.includeProcessActivity {
            drawProcessActivity(data: data, configuration: configuration, context: context)
        }
        
        // Draw footer
        drawReportFooter(data: data, context: context)
    }
    
    // MARK: - Header
    private func drawReportHeader(data: ExportData, configuration: ExportConfiguration, context: CGContext) {
        let headerY = pageSize.height - margin - headerHeight
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        let title = "Work Life Balance Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: margin,
            y: headerY + 40,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Date range
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.gray
        ]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let startDate = dateFormatter.string(from: data.dateRange.start)
        let endDate = dateFormatter.string(from: data.dateRange.end)
        let subtitle = "Period: \(startDate) to \(endDate)"
        let subtitleRect = CGRect(
            x: margin,
            y: headerY + 15,
            width: pageSize.width - 2 * margin,
            height: 20
        )
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
        
        // Generation date
        let generatedText = "Generated on \(dateFormatter.string(from: Date()))"
        let generatedRect = CGRect(
            x: margin,
            y: headerY,
            width: pageSize.width - 2 * margin,
            height: 15
        )
        generatedText.draw(in: generatedRect, withAttributes: subtitleAttributes)
        
        // Draw separator line
        context.setStrokeColor(NSColor.lightGray.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: headerY - 10))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: headerY - 10))
        context.strokePath()
        
        currentPageY = headerY - 30
    }
    
    // MARK: - Executive Summary
    private func drawExecutiveSummary(data: ExportData, context: CGContext) {
        checkPageBreak(requiredHeight: 200)
        
        // Section title
        drawSectionTitle("Executive Summary", context: context)
        
        // Calculate summary statistics
        let totalWorkTime = data.dayStatistics.reduce(0) { $0 + $1.totalWorkTime }
        let totalRestTime = data.dayStatistics.reduce(0) { $0 + $1.totalRestTime }
        let totalIdleTime = data.dayStatistics.reduce(0) { $0 + $1.totalIdleTime }
        let totalTime = totalWorkTime + totalRestTime + totalIdleTime
        let averageProductivity = data.dayStatistics.isEmpty ? 0 : 
            data.dayStatistics.reduce(0) { $0 + $1.productivityPercentage } / Double(data.dayStatistics.count)
        let totalSessions = data.dayStatistics.reduce(0) { $0 + $1.sessions.count }
        
        // Draw summary boxes
        let boxWidth = (pageSize.width - 2 * margin - 20) / 2
        let boxHeight: CGFloat = 60
        
        // Left column
        drawSummaryBox(
            title: "Total Work Time",
            value: formatDuration(totalWorkTime),
            x: margin,
            y: currentPageY - boxHeight,
            width: boxWidth,
            height: boxHeight,
            color: NSColor.systemGreen,
            context: context
        )
        
        drawSummaryBox(
            title: "Total Rest Time",
            value: formatDuration(totalRestTime),
            x: margin,
            y: currentPageY - 2 * boxHeight - 10,
            width: boxWidth,
            height: boxHeight,
            color: NSColor.systemBlue,
            context: context
        )
        
        // Right column
        drawSummaryBox(
            title: "Average Productivity",
            value: String(format: "%.1f%%", averageProductivity),
            x: margin + boxWidth + 20,
            y: currentPageY - boxHeight,
            width: boxWidth,
            height: boxHeight,
            color: NSColor.systemOrange,
            context: context
        )
        
        drawSummaryBox(
            title: "Total Sessions",
            value: "\(totalSessions)",
            x: margin + boxWidth + 20,
            y: currentPageY - 2 * boxHeight - 10,
            width: boxWidth,
            height: boxHeight,
            color: NSColor.systemPurple,
            context: context
        )
        
        currentPageY -= 2 * boxHeight + 40
    }
    
    // MARK: - Charts
    private func drawCharts(data: ExportData, context: CGContext) async {
        checkPageBreak(requiredHeight: 300)
        
        drawSectionTitle("Productivity Trends", context: context)
        
        // Create productivity chart
        let chartFrame = CGRect(
            x: margin,
            y: currentPageY - 250,
            width: pageSize.width - 2 * margin,
            height: 200
        )
        
        await drawProductivityChart(data: data, frame: chartFrame, context: context)
        
        currentPageY -= 280
    }
    
    private func drawProductivityChart(data: ExportData, frame: CGRect, context: CGContext) async {
        // Draw chart background
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.fill(frame)
        
        context.setStrokeColor(NSColor.controlColor.cgColor)
        context.setLineWidth(1)
        context.stroke(frame)
        
        guard !data.dayStatistics.isEmpty else {
            // Draw "No Data" message
            let noDataText = "No data available for chart"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let textSize = noDataText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: frame.midX - textSize.width / 2,
                y: frame.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            noDataText.draw(in: textRect, withAttributes: attributes)
            return
        }
        
        // Draw productivity line chart
        let chartPadding: CGFloat = 20
        let chartRect = frame.insetBy(dx: chartPadding, dy: chartPadding)
        
        let maxProductivity: Double = 100
        let minProductivity: Double = 0
        let productivityRange = maxProductivity - minProductivity
        
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2)
        
        // Draw chart lines
        for (index, dayStats) in data.dayStatistics.enumerated() {
            let x = chartRect.minX + (CGFloat(index) / CGFloat(data.dayStatistics.count - 1)) * chartRect.width
            let y = chartRect.minY + CGFloat((dayStats.productivityPercentage - minProductivity) / productivityRange) * chartRect.height
            
            if index == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.strokePath()
        
        // Draw data points
        context.setFillColor(NSColor.systemBlue.cgColor)
        for (index, dayStats) in data.dayStatistics.enumerated() {
            let x = chartRect.minX + (CGFloat(index) / CGFloat(data.dayStatistics.count - 1)) * chartRect.width
            let y = chartRect.minY + CGFloat((dayStats.productivityPercentage - minProductivity) / productivityRange) * chartRect.height
            
            context.fillEllipse(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
        }
        
        // Draw axis labels
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.labelColor
        ]
        
        // Y-axis labels
        for i in 0...5 {
            let value = minProductivity + (productivityRange / 5) * Double(i)
            let text = String(format: "%.0f%%", value)
            let y = chartRect.minY + CGFloat(i) / 5 * chartRect.height
            text.draw(at: CGPoint(x: chartRect.minX - 30, y: y - 5), withAttributes: labelAttributes)
        }
        
        // X-axis labels (show first, middle, and last dates)
        if data.dayStatistics.count >= 3 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd"
            
            let firstDate = dateFormatter.string(from: data.dayStatistics.first!.date)
            let middleDate = dateFormatter.string(from: data.dayStatistics[data.dayStatistics.count / 2].date)
            let lastDate = dateFormatter.string(from: data.dayStatistics.last!.date)
            
            firstDate.draw(at: CGPoint(x: chartRect.minX, y: chartRect.minY - 20), withAttributes: labelAttributes)
            middleDate.draw(at: CGPoint(x: chartRect.midX - 15, y: chartRect.minY - 20), withAttributes: labelAttributes)
            lastDate.draw(at: CGPoint(x: chartRect.maxX - 30, y: chartRect.minY - 20), withAttributes: labelAttributes)
        }
    }
    
    // MARK: - Detailed Statistics
    private func drawDetailedStatistics(data: ExportData, context: CGContext) {
        checkPageBreak(requiredHeight: 300)
        
        drawSectionTitle("Daily Statistics", context: context)
        
        // Table headers
        let headers = ["Date", "Work Time", "Rest Time", "Idle Time", "Productivity", "Sessions"]
        let columnWidths: [CGFloat] = [100, 80, 80, 80, 80, 60]
        let tableWidth = columnWidths.reduce(0, +)
        let startX = (pageSize.width - tableWidth) / 2
        
        // Draw table header
        var currentX = startX
        for (index, header) in headers.enumerated() {
            let headerRect = CGRect(
                x: currentX,
                y: currentPageY - 25,
                width: columnWidths[index],
                height: 20
            )
            
            // Header background
            context.setFillColor(NSColor.controlBackgroundColor.cgColor)
            context.fill(headerRect)
            
            // Header border
            context.setStrokeColor(NSColor.controlColor.cgColor)
            context.setLineWidth(0.5)
            context.stroke(headerRect)
            
            // Header text
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 10),
                .foregroundColor: NSColor.labelColor
            ]
            header.draw(in: headerRect.insetBy(dx: 4, dy: 2), withAttributes: headerAttributes)
            
            currentX += columnWidths[index]
        }
        
        currentPageY -= 25
        
        // Draw table rows
        let rowAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.labelColor
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy"
        
        for dayStats in data.dayStatistics {
            checkPageBreak(requiredHeight: 20)
            
            let rowData = [
                dateFormatter.string(from: dayStats.date),
                formatDuration(dayStats.totalWorkTime),
                formatDuration(dayStats.totalRestTime),
                formatDuration(dayStats.totalIdleTime),
                String(format: "%.1f%%", dayStats.productivityPercentage),
                "\(dayStats.sessions.count)"
            ]
            
            currentX = startX
            for (index, data) in rowData.enumerated() {
                let cellRect = CGRect(
                    x: currentX,
                    y: currentPageY - 20,
                    width: columnWidths[index],
                    height: 20
                )
                
                // Cell border
                context.setStrokeColor(NSColor.separatorColor.cgColor)
                context.setLineWidth(0.25)
                context.stroke(cellRect)
                
                // Cell text
                data.draw(in: cellRect.insetBy(dx: 4, dy: 2), withAttributes: rowAttributes)
                
                currentX += columnWidths[index]
            }
            
            currentPageY -= 20
        }
        
        currentPageY -= 20
    }
    
    // MARK: - Work Sessions
    private func drawWorkSessions(data: ExportData, configuration: ExportConfiguration, context: CGContext) {
        checkPageBreak(requiredHeight: 100)
        
        drawSectionTitle("Recent Work Sessions", context: context)
        
        let allSessions = data.dayStatistics.flatMap { $0.sessions }
            .filter { $0.type == .work }
            .sorted { $0.startTime > $1.startTime }
            .prefix(20) // Show last 20 sessions
        
        if allSessions.isEmpty {
            let noDataText = "No work sessions found for the selected period."
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let textRect = CGRect(x: margin, y: currentPageY - 30, width: pageSize.width - 2 * margin, height: 20)
            noDataText.draw(in: textRect, withAttributes: attributes)
            currentPageY -= 50
            return
        }
        
        let sessionAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.labelColor
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd HH:mm"
        
        for session in allSessions {
            checkPageBreak(requiredHeight: 25)
            
            let duration = formatDuration(session.duration)
            let startTime = dateFormatter.string(from: session.startTime)
            let apps = session.associatedApps.isEmpty ? "No apps tracked" : 
                       configuration.privacyMode ? "[Privacy Mode]" : session.associatedApps.joined(separator: ", ")
            
            let sessionText = "• \(startTime) - \(duration) - \(apps)"
            let sessionRect = CGRect(x: margin, y: currentPageY - 20, width: pageSize.width - 2 * margin, height: 15)
            sessionText.draw(in: sessionRect, withAttributes: sessionAttributes)
            
            currentPageY -= 20
        }
        
        currentPageY -= 20
    }
    
    // MARK: - Process Activity
    private func drawProcessActivity(data: ExportData, configuration: ExportConfiguration, context: CGContext) {
        checkPageBreak(requiredHeight: 100)
        
        drawSectionTitle("Top Applications", context: context)
        
        // Aggregate process activity across all days
        var appUsage: [String: TimeInterval] = [:]
        
        for dayStats in data.dayStatistics {
            for activity in dayStats.processActivities {
                let appName = configuration.privacyMode ? "Application \(abs(activity.applicationName.hashValue) % 100)" : activity.applicationName
                appUsage[appName, default: 0] += activity.totalActiveTime
            }
        }
        
        let sortedApps = appUsage.sorted { $0.value > $1.value }.prefix(10)
        
        if sortedApps.isEmpty {
            let noDataText = "No application activity data found."
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let textRect = CGRect(x: margin, y: currentPageY - 30, width: pageSize.width - 2 * margin, height: 20)
            noDataText.draw(in: textRect, withAttributes: attributes)
            currentPageY -= 50
            return
        }
        
        let appAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.labelColor
        ]
        
        for (index, app) in sortedApps.enumerated() {
            checkPageBreak(requiredHeight: 25)
            
            let duration = formatDuration(app.value)
            let appText = "\(index + 1). \(app.key) - \(duration)"
            let appRect = CGRect(x: margin, y: currentPageY - 20, width: pageSize.width - 2 * margin, height: 15)
            appText.draw(in: appRect, withAttributes: appAttributes)
            
            currentPageY -= 20
        }
        
        currentPageY -= 20
    }
    
    // MARK: - Footer
    private func drawReportFooter(data: ExportData, context: CGContext) {
        let footerY: CGFloat = margin
        
        // Footer separator line
        context.setStrokeColor(NSColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: footerY + 30))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: footerY + 30))
        context.strokePath()
        
        // Footer text
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let footerText = "Generated by Work Life Balance v\(appVersion) - Page \(pageNumber)"
        let footerRect = CGRect(x: margin, y: footerY, width: pageSize.width - 2 * margin, height: 20)
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
    }
    
    // MARK: - Helper Methods
    private func drawSectionTitle(_ title: String, context: CGContext) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.labelColor
        ]
        
        let titleRect = CGRect(
            x: margin,
            y: currentPageY - 25,
            width: pageSize.width - 2 * margin,
            height: 20
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        currentPageY -= 40
    }
    
    private func drawSummaryBox(
        title: String,
        value: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        color: NSColor,
        context: CGContext
    ) {
        let boxRect = CGRect(x: x, y: y, width: width, height: height)
        
        // Box background
        context.setFillColor(color.withAlphaComponent(0.1).cgColor)
        context.fill(boxRect)
        
        // Box border
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        context.stroke(boxRect)
        
        // Value text
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: color
        ]
        let valueSize = value.size(withAttributes: valueAttributes)
        let valueRect = CGRect(
            x: x + (width - valueSize.width) / 2,
            y: y + height - 25,
            width: valueSize.width,
            height: valueSize.height
        )
        value.draw(in: valueRect, withAttributes: valueAttributes)
        
        // Title text
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: x + (width - titleSize.width) / 2,
            y: y + 5,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
    }
    
    private func checkPageBreak(requiredHeight: CGFloat) {
        if currentPageY - requiredHeight < margin + footerHeight {
            // Start new page
            guard let context = pdfContext else { return }
            
            drawReportFooter(data: ExportData(
                dateRange: DateInterval(start: Date(), end: Date()),
                dayStatistics: [],
                timeEntries: [],
                userPreferences: nil,
                metadata: ExportMetadata()
            ), context: context)
            
            context.endPDFPage()
            context.beginPDFPage(nil)
            
            pageNumber += 1
            currentPageY = pageSize.height - margin - headerHeight
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}