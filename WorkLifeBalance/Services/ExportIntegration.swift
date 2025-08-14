//
//  ExportIntegration.swift
//  WorkLifeBalance
//
//  Integration layer for export functionality with the main app
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Export Integration
extension AppStateManager {
    
    /// Show the export dialog
    func showExportDialog() {
        let exportWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 650),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        exportWindow.title = "Export Data"
        exportWindow.center()
        exportWindow.contentView = NSHostingView(rootView: ExportView())
        
        exportWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Quick export with default settings
    func quickExport(format: ExportFormat = .csv) async throws -> URL {
        let exportManager = ExportManager.shared
        
        let configuration = ExportConfiguration(
            format: format,
            dateRange: .lastWeek,
            includeWorkSessions: true,
            includeProcessActivity: false,
            includeStatistics: true,
            includeCharts: false,
            includeSettings: false
        )
        
        return try await exportManager.exportData(configuration: configuration) { _ in }
    }
    
    /// Generate a summary report for today
    func generateTodaysSummary() async throws -> String {
        let databaseManager = await DatabaseManager()
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? today
        
        let summary = try await databaseManager.getSummaryStatistics(from: startOfDay, to: endOfDay)
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        
        let workTime = formatter.string(from: summary.totalWorkTime) ?? "0 minutes"
        let restTime = formatter.string(from: summary.totalRestTime) ?? "0 minutes"
        
        return """
        Today's Summary:
        
        Work Time: \(workTime)
        Rest Time: \(restTime)
        Productivity: \(String(format: "%.1f%%", summary.averageProductivity))
        
        Generated on \(DateFormatter.localizedString(from: today, dateStyle: .full, timeStyle: .short))
        """
    }
}

// MARK: - Menu Bar Integration
extension NSMenu {
    
    /// Add export menu items to the app's menu
    @MainActor
    static func createExportMenu() -> NSMenu {
        let exportMenu = NSMenu(title: "Export")
        
        // Quick CSV Export
        let csvItem = NSMenuItem(
            title: "Export as CSV...",
            action: #selector(ExportMenuHandler.exportAsCSV),
            keyEquivalent: ""
        )
        csvItem.target = ExportMenuHandler.shared
        exportMenu.addItem(csvItem)
        
        // Quick JSON Export
        let jsonItem = NSMenuItem(
            title: "Export as JSON...",
            action: #selector(ExportMenuHandler.exportAsJSON),
            keyEquivalent: ""
        )
        jsonItem.target = ExportMenuHandler.shared
        exportMenu.addItem(jsonItem)
        
        // Generate PDF Report
        let pdfItem = NSMenuItem(
            title: "Generate PDF Report...",
            action: #selector(ExportMenuHandler.generatePDFReport),
            keyEquivalent: ""
        )
        pdfItem.target = ExportMenuHandler.shared
        exportMenu.addItem(pdfItem)
        
        exportMenu.addItem(NSMenuItem.separator())
        
        // Full Export Dialog
        let fullExportItem = NSMenuItem(
            title: "Export Options...",
            action: #selector(ExportMenuHandler.showExportDialog),
            keyEquivalent: "e"
        )
        fullExportItem.keyEquivalentModifierMask = [.command, .shift]
        fullExportItem.target = ExportMenuHandler.shared
        exportMenu.addItem(fullExportItem)
        
        return exportMenu
    }
}

// MARK: - Export Menu Handler
@MainActor
class ExportMenuHandler: NSObject {
    @MainActor static let shared = ExportMenuHandler()
    
    @objc func exportAsCSV() {
        Task {
            do {
                let url = try await AppStateManager.shared.quickExport(format: .csv)
                await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                await MainActor.run {
                    showErrorAlert(message: "Failed to export CSV: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc func exportAsJSON() {
        Task {
            do {
                let url = try await AppStateManager.shared.quickExport(format: .json)
                await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                await MainActor.run {
                    showErrorAlert(message: "Failed to export JSON: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc func generatePDFReport() {
        Task {
            do {
                let url = try await AppStateManager.shared.quickExport(format: .pdf)
                await MainActor.run {
                    NSWorkspace.shared.open(url)
                }
            } catch {
                await MainActor.run {
                    showErrorAlert(message: "Failed to generate PDF report: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc func showExportDialog() {
        AppStateManager.shared.showExportDialog()
    }
    
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Export Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - SettingsView Integration
extension SettingsView {
    
    /// Add export section to settings
    var exportSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Data Export", systemImage: "square.and.arrow.up")
                    .font(.headline)
                
                Text("Export your Work Life Balance data for backup or analysis.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Quick CSV Export") {
                        Task {
                            do {
                                let url = try await AppStateManager.shared.quickExport(format: .csv)
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } catch {
                                print("Export failed: \(error)")
                            }
                        }
                    }
                    
                    Button("Export Options...") {
                        AppStateManager.shared.showExportDialog()
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Button("Generate Today's Summary") {
                        Task {
                            do {
                                let summary = try await AppStateManager.shared.generateTodaysSummary()
                                showSummaryAlert(summary: summary)
                            } catch {
                                print("Summary generation failed: \(error)")
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private func showSummaryAlert(summary: String) {
        let alert = NSAlert()
        alert.messageText = "Today's Summary"
        alert.informativeText = summary
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy to Clipboard")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(summary, forType: .string)
        }
    }
}

// MARK: - Keyboard Shortcuts
extension NSApplication {
    
    /// Set up export-related keyboard shortcuts
    func setupExportKeyboardShortcuts() {
        // Add to main menu if needed
        if let mainMenu = NSApp.mainMenu {
            // Find or create File menu
            var fileMenu: NSMenu?
            
            for menuItem in mainMenu.items {
                if menuItem.title == "File" {
                    fileMenu = menuItem.submenu
                    break
                }
            }
            
            if fileMenu == nil {
                let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
                fileMenu = NSMenu(title: "File")
                fileMenuItem.submenu = fileMenu
                mainMenu.insertItem(fileMenuItem, at: 1)
            }
            
            // Add export submenu
            if let fileMenu = fileMenu {
                fileMenu.addItem(NSMenuItem.separator())
                
                let exportMenuItem = NSMenuItem(title: "Export", action: nil, keyEquivalent: "")
                exportMenuItem.submenu = NSMenu.createExportMenu()
                fileMenu.addItem(exportMenuItem)
            }
        }
    }
}