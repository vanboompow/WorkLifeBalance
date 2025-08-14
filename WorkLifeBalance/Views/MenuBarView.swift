//
//  MenuBarView.swift
//  WorkLifeBalance
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var showingProgressRing = true
    
    var body: some View {
        ZStack {
            // Progress ring (optional, can be toggled)
            if showingProgressRing {
                ProgressRing()
                    .frame(width: 20, height: 20)
            }
            
            // Main timer icon
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(appState.currentState.color)
                .animation(.smooth, value: appState.currentState)
        }
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
        .onTapGesture {
            // Toggle progress ring visibility
            withAnimation(.smooth) {
                showingProgressRing.toggle()
            }
        }
    }
    
    private struct ProgressRing: View {
        @EnvironmentObject var appState: AppStateManager
        
        private var totalTime: TimeInterval {
            appState.workTime + appState.restTime + appState.idleTime
        }
        
        private var workProgress: Double {
            guard totalTime > 0 else { return 0 }
            return appState.workTime / totalTime
        }
        
        private var restProgress: Double {
            guard totalTime > 0 else { return 0 }
            return appState.restTime / totalTime
        }
        
        var body: some View {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                
                // Work progress
                Circle()
                    .trim(from: 0, to: workProgress)
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: workProgress)
                
                // Rest progress (starts where work ends)
                Circle()
                    .trim(from: workProgress, to: workProgress + restProgress)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: restProgress)
            }
        }
    }
}

// Context Menu for Menu Bar
struct MenuBarContextMenu: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current Status
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Status: \(appState.currentState.description)")
                    .font(.headline)
                    .foregroundColor(appState.currentState.color)
                
                Text("Work: \(appState.formattedWorkTime)")
                Text("Rest: \(appState.formattedRestTime)")
                Text("Idle: \(appState.formattedIdleTime)")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Quick Actions
            Group {
                Button("Start Working") {
                    appState.startWork()
                }
                .disabled(appState.currentState == .working)
                
                Button("Take Break") {
                    appState.startRest()
                }
                .disabled(appState.currentState == .resting)
                
                Divider()
                
                Button("Settings...") {
                    appState.showSettings()
                }
                
                Button("Show Dashboard") {
                    // Will be implemented with DashboardWindow
                }
                
                Divider()
                
                Button("Quit Work Life Balance") {
                    Task { @MainActor in
                        await appState.saveCurrentSession()
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }
}

// Menu Bar Manager for handling the actual NSStatusItem
class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var appState: AppStateManager
    
    init(appState: AppStateManager) {
        self.appState = appState
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Set up the menu bar button view
            let menuBarView = MenuBarView()
                .environmentObject(appState)
            
            button.subviews.removeAll()
            let hostingView = NSHostingView(rootView: menuBarView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
            button.addSubview(hostingView)
            button.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
            
            // Set up context menu
            let contextMenu = NSMenu()
            contextMenu.delegate = self
            statusItem?.menu = contextMenu
        }
    }
    
    func updateIcon() {
        // Force update of the menu bar view when state changes
        if let button = statusItem?.button {
            button.needsDisplay = true
        }
    }
}

extension MenuBarManager: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        // Current Status Section
        let statusItem = NSMenuItem()
        statusItem.title = "Current Status: \(appState.currentState.description)"
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        let workTimeItem = NSMenuItem()
        workTimeItem.title = "Work: \(appState.formattedWorkTime)"
        workTimeItem.isEnabled = false
        menu.addItem(workTimeItem)
        
        let restTimeItem = NSMenuItem()
        restTimeItem.title = "Rest: \(appState.formattedRestTime)"
        restTimeItem.isEnabled = false
        menu.addItem(restTimeItem)
        
        let idleTimeItem = NSMenuItem()
        idleTimeItem.title = "Idle: \(appState.formattedIdleTime)"
        idleTimeItem.isEnabled = false
        menu.addItem(idleTimeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick Actions
        let startWorkItem = NSMenuItem(title: "Start Working", action: #selector(startWork), keyEquivalent: "w")
        startWorkItem.target = self
        startWorkItem.isEnabled = appState.currentState != .working
        menu.addItem(startWorkItem)
        
        let takeBreakItem = NSMenuItem(title: "Take Break", action: #selector(takeBreak), keyEquivalent: "b")
        takeBreakItem.target = self
        takeBreakItem.isEnabled = appState.currentState != .resting
        menu.addItem(takeBreakItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings and Dashboard
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let dashboardItem = NSMenuItem(title: "Show Dashboard", action: #selector(showDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Work Life Balance", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @MainActor
    @objc private func startWork() {
        Task {
            await appState.startWork()
        }
    }
    
    @MainActor
    @objc private func takeBreak() {
        Task {
            await appState.startRest()
        }
    }
    
    @MainActor
    @objc private func showSettings() {
        Task {
            await appState.showSettings()
        }
    }
    
    @MainActor
    @objc private func showDashboard() {
        // Will be implemented with DashboardWindow
        print("Show Dashboard - not implemented yet")
    }
    
    @MainActor
    @objc private func quit() {
        Task {
            await appState.saveCurrentSession()
            NSApplication.shared.terminate(nil)
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppStateManager.shared)
}