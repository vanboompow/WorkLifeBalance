//
//  AppStateManager.swift
//  WorkLifeBalance
//

import Foundation
import SwiftUI
import Combine
import AppKit

enum WorkState {
    case working
    case resting
    case idle
    
    var description: String {
        switch self {
        case .working: return "Working"
        case .resting: return "Resting"
        case .idle: return "Idle"
        }
    }
    
    var color: Color {
        switch self {
        case .working: return .green
        case .resting: return .blue
        case .idle: return .gray
        }
    }
}

class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var currentState: WorkState = .idle
    @Published var workTime: TimeInterval = 0
    @Published var restTime: TimeInterval = 0
    @Published var idleTime: TimeInterval = 0
    
    private var stateTimer: Timer?
    private var activityMonitor: ActivityMonitor?
    private var databaseManager: DatabaseManager?
    private var settingsWindow: NSWindow?
    
    var formattedWorkTime: String {
        formatTime(workTime)
    }
    
    var formattedRestTime: String {
        formatTime(restTime)
    }
    
    var formattedIdleTime: String {
        formatTime(idleTime)
    }
    
    private init() {
        setupMonitoring()
        loadTodayData()
    }
    
    deinit {
        // Clean up resources
        stateTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    private func setupMonitoring() {
        activityMonitor = ActivityMonitor()
        databaseManager = DatabaseManager()
        
        // Start monitoring
        startStateTimer()
        
        // Monitor app changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    private func startStateTimer() {
        stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateState()
            self.updateTime()
        }
    }
    
    private func updateState() {
        // Check for idle
        if let idleSeconds = activityMonitor?.getIdleTime(), idleSeconds > 300 {
            if currentState != .idle {
                currentState = .idle
            }
            return
        }
        
        // Check active app for work detection
        if UserDefaults.standard.bool(forKey: "autoDetectWork") {
            if let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName {
                let workingApps = UserDefaults.standard.string(forKey: "workingApps") ?? ""
                let appsList = workingApps.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                
                if appsList.contains(activeApp) {
                    if currentState != .working {
                        currentState = .working
                    }
                } else if currentState == .working {
                    currentState = .resting
                }
            }
        }
    }
    
    private func updateTime() {
        switch currentState {
        case .working:
            workTime += 1
        case .resting:
            restTime += 1
        case .idle:
            idleTime += 1
        }
        
        // Save to database every minute
        if Int(workTime + restTime + idleTime) % 60 == 0 {
            saveToDatabase()
        }
    }
    
    @objc private func activeAppChanged() {
        updateState()
    }
    
    func startWork() {
        currentState = .working
    }
    
    func startRest() {
        currentState = .resting
    }
    
    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Work Life Balance Settings"
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView().environmentObject(self))
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func loadTodayData() {
        // Load today's data from database
        if let data = databaseManager?.getTodayData() {
            workTime = data.workTime
            restTime = data.restTime
            idleTime = data.idleTime
        }
    }
    
    private func saveToDatabase() {
        databaseManager?.saveTimeEntry(
            state: currentState,
            workTime: workTime,
            restTime: restTime,
            idleTime: idleTime
        )
    }
}
