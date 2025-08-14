//
//  ExportView.swift
//  WorkLifeBalance
//
//  Export dialog with comprehensive options for data export
//

import SwiftUI
import AppKit

// MARK: - ExportConfiguration
struct ExportConfiguration {
    var format: ExportFormat = .csv
    var dateRange: DateRange = .lastWeek
    var customStartDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
    var customEndDate: Date = Date()
    var includeWorkSessions: Bool = true
    var includeProcessActivity: Bool = true
    var includeStatistics: Bool = true
    var includeCharts: Bool = true
    var includeSettings: Bool = false
    var privacyMode: Bool = false
    var groupByDay: Bool = true
    var includeIdleTime: Bool = true
    var fileNamingPattern: String = "WorkLifeBalance_Export_{date}"
    
    // Computed properties
    var effectiveStartDate: Date {
        switch dateRange {
        case .today:
            return Calendar.current.startOfDay(for: Date())
        case .yesterday:
            return Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        case .lastWeek:
            return Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        case .lastMonth:
            return Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .last3Months:
            return Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .custom:
            return customStartDate
        }
    }
    
    var effectiveEndDate: Date {
        switch dateRange {
        case .custom:
            return customEndDate
        default:
            return Date()
        }
    }
    
    var estimatedFileSize: String {
        // Rough estimation based on selected options
        let baseSize = 1024 // Base size in bytes
        let multiplier = (includeWorkSessions ? 2 : 1) *
                        (includeProcessActivity ? 3 : 1) *
                        (includeCharts ? 10 : 1)
        let estimatedBytes = baseSize * multiplier
        
        return ByteCountFormatter.string(fromByteCount: Int64(estimatedBytes), countStyle: .binary)
    }
}

enum DateRange: String, CaseIterable {
    case today = "today"
    case yesterday = "yesterday"
    case lastWeek = "lastWeek"
    case lastMonth = "lastMonth"
    case last3Months = "last3Months"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        case .last3Months: return "Last 3 Months"
        case .custom: return "Custom Range"
        }
    }
}

// MARK: - ExportView
struct ExportView: View {
    @StateObject private var exportManager = ExportManager.shared
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var configuration = ExportConfiguration()
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var exportError: String?
    @State private var showingFilePicker = false
    @State private var exportComplete = false
    @State private var exportedFileURL: URL?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    formatSection
                    dateRangeSection
                    dataOptionsSection
                    
                    if configuration.format == .pdf {
                        pdfOptionsSection
                    }
                    
                    privacySection
                    previewSection
                }
                .padding()
            }
            
            Divider()
            
            // Footer with actions
            footerView
        }
        .frame(width: 500, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadUserPreferences()
        }
        .alert("Export Error", isPresented: .init(
            get: { exportError != nil },
            set: { _ in exportError = nil }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .alert("Export Complete", isPresented: $exportComplete) {
            Button("Open File") {
                if let url = exportedFileURL {
                    NSWorkspace.shared.open(url)
                }
                exportComplete = false
            }
            Button("Show in Finder") {
                if let url = exportedFileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                exportComplete = false
            }
            Button("OK") {
                exportComplete = false
            }
        } message: {
            Text("Your data has been exported successfully.")
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Export your Work Life Balance data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding()
    }
    
    // MARK: - Format Selection
    private var formatSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Export Format", systemImage: "doc.badge.gearshape")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        FormatCard(
                            format: format,
                            isSelected: configuration.format == format
                        ) {
                            configuration.format = format
                        }
                    }
                }
                
                Text(formatDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }
    
    private var formatDescription: String {
        switch configuration.format {
        case .csv:
            return "Comma-separated values file, perfect for spreadsheet applications and data analysis."
        case .json:
            return "Structured data format, ideal for developers and data processing applications."
        case .pdf:
            return "Professional report with charts and visualizations, ready for sharing and presentation."
        case .html:
            return "Web page format with interactive elements and styled presentation."
        case .excel:
            return "Microsoft Excel format with multiple sheets and formatted data."
        }
    }
    
    // MARK: - Date Range Selection
    private var dateRangeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Date Range", systemImage: "calendar")
                    .font(.headline)
                
                Picker("Date Range", selection: $configuration.dateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                
                if configuration.dateRange == .custom {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Start Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $configuration.customStartDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("End Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $configuration.customEndDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .padding(.top, 8)
                }
                
                Text(dateRangeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: configuration.effectiveStartDate)
        let end = formatter.string(from: configuration.effectiveEndDate)
        return "Exporting data from \(start) to \(end)"
    }
    
    // MARK: - Data Options
    private var dataOptionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Data Options", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Work Sessions", isOn: $configuration.includeWorkSessions)
                    Toggle("Process Activity", isOn: $configuration.includeProcessActivity)
                    Toggle("Daily Statistics", isOn: $configuration.includeStatistics)
                    Toggle("Include Idle Time", isOn: $configuration.includeIdleTime)
                    Toggle("Group by Day", isOn: $configuration.groupByDay)
                    Toggle("Include App Settings", isOn: $configuration.includeSettings)
                }
                
                Text("Select which types of data to include in your export.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - PDF Options
    private var pdfOptionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("PDF Options", systemImage: "doc.richtext")
                    .font(.headline)
                
                Toggle("Include Charts and Visualizations", isOn: $configuration.includeCharts)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("File Naming Pattern")
                        .font(.subheadline)
                    
                    TextField("Pattern", text: $configuration.fileNamingPattern)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Use {date}, {time}, {format} as placeholders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Privacy & Security", systemImage: "lock.shield")
                    .font(.headline)
                
                Toggle("Privacy Mode", isOn: $configuration.privacyMode)
                
                Text("Privacy mode obscures application names and window titles in the export.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Export Preview", systemImage: "eye")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated File Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(configuration.estimatedFileSize)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Date Range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(daysInRange) days")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
    
    private var daysInRange: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: configuration.effectiveStartDate, to: configuration.effectiveEndDate)
        return max(1, components.day ?? 1)
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            if isExporting {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Exporting...")
                        .font(.caption)
                    Text("\(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Export") {
                startExport()
            }
            .disabled(isExporting || !hasValidConfiguration)
            .keyboardShortcut(.return)
        }
        .padding()
    }
    
    private var hasValidConfiguration: Bool {
        configuration.includeWorkSessions || 
        configuration.includeProcessActivity || 
        configuration.includeStatistics
    }
    
    // MARK: - Helper Methods
    private func loadUserPreferences() {
        configuration.format = preferencesManager.preferences.export.defaultFormat
        configuration.includeCharts = preferencesManager.preferences.export.includeCharts
        configuration.privacyMode = preferencesManager.preferences.advanced.privacyMode
    }
    
    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        Task {
            do {
                let url = try await exportManager.exportData(configuration: configuration) { progress in
                    await MainActor.run {
                        exportProgress = progress
                    }
                }
                
                await MainActor.run {
                    isExporting = false
                    exportedFileURL = url
                    exportComplete = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Format Card
struct FormatCard: View {
    let format: ExportFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(format.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconName: String {
        switch format {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .pdf: return "doc.richtext"
        case .html: return "safari"
        case .excel: return "tablecells.badge.ellipsis"
        }
    }
}

// MARK: - Preview
#Preview {
    ExportView()
}