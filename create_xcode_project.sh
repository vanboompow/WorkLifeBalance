#!/bin/bash

# Create the Xcode project structure for WorkLifeBalance macOS port

PROJECT_NAME="WorkLifeBalance"
PROJECT_DIR="/Users/ryanstern/WorkLifeBalance-macOS"

cd "$PROJECT_DIR"

# Create directory structure
mkdir -p "$PROJECT_NAME" "$PROJECT_NAME/Models" "$PROJECT_NAME/Views" "$PROJECT_NAME/ViewModels" "$PROJECT_NAME/Services" "$PROJECT_NAME/Utilities" "$PROJECT_NAME/Resources"

# Create Package.swift for Swift Package Manager
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkLifeBalance",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WorkLifeBalance",
            targets: ["WorkLifeBalance"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.0"),
    ],
    targets: [
        .executableTarget(
            name: "WorkLifeBalance",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "WorkLifeBalance"
        ),
        .testTarget(
            name: "WorkLifeBalanceTests",
            dependencies: ["WorkLifeBalance"]
        ),
    ]
)
EOF

# Create main app file
cat > "$PROJECT_NAME/WorkLifeBalanceApp.swift" << 'EOF'
//
//  WorkLifeBalanceApp.swift
//  WorkLifeBalance
//
//  macOS port of the original Windows WPF application
//

import SwiftUI
import AppKit

@main
struct WorkLifeBalanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover = NSPopover()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up menu bar icon
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Work Life Balance")
            button.action = #selector(togglePopover)
        }
        
        // Configure popover
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView())
    }
    
    @objc func togglePopover() {
        if let button = statusBarItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
EOF

# Create ContentView
cat > "$PROJECT_NAME/Views/ContentView.swift" << 'EOF'
//
//  ContentView.swift
//  WorkLifeBalance
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Display
            StatusView()
            
            // Time Tracking Display
            TimeTrackingView()
            
            // Control Buttons
            ControlsView()
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

struct StatusView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack {
            Text("Current Status")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(appState.currentState.color)
                    .frame(width: 12, height: 12)
                
                Text(appState.currentState.description)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TimeTrackingView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Activity")
                .font(.headline)
            
            HStack {
                Label("Work Time", systemImage: "desktopcomputer")
                Spacer()
                Text(appState.formattedWorkTime)
            }
            
            HStack {
                Label("Rest Time", systemImage: "cup.and.saucer")
                Spacer()
                Text(appState.formattedRestTime)
            }
            
            HStack {
                Label("Idle Time", systemImage: "moon.zzz")
                Spacer()
                Text(appState.formattedIdleTime)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ControlsView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        HStack(spacing: 20) {
            Button("Start Work") {
                appState.startWork()
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.currentState == .working)
            
            Button("Take Break") {
                appState.startRest()
            }
            .buttonStyle(.bordered)
            .disabled(appState.currentState == .resting)
            
            Button("Settings") {
                NSApp.sendAction(#selector(AppDelegate.showPreferences), to: nil, from: nil)
            }
            .buttonStyle(.bordered)
        }
    }
}

struct PopoverView: View {
    var body: some View {
        ContentView()
            .frame(width: 300, height: 400)
    }
}
EOF

# Create Settings View
cat > "$PROJECT_NAME/Views/SettingsView.swift" << 'EOF'
//
//  SettingsView.swift
//  WorkLifeBalance
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("autoDetectWork") private var autoDetectWork = true
    @AppStorage("idleTimeMinutes") private var idleTimeMinutes = 5
    @AppStorage("workingApps") private var workingApps = "Xcode,Visual Studio Code,Terminal"
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ApplicationsSettingsView()
                .tabItem {
                    Label("Applications", systemImage: "app.badge")
                }
            
            NotificationsSettingsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("autoDetectWork") private var autoDetectWork = true
    @AppStorage("idleTimeMinutes") private var idleTimeMinutes = 5
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        Form {
            Toggle("Auto-detect work state", isOn: $autoDetectWork)
            
            HStack {
                Text("Idle time (minutes):")
                TextField("", value: $idleTimeMinutes, format: .number)
                    .frame(width: 50)
            }
            
            Toggle("Launch at login", isOn: $launchAtLogin)
        }
        .padding()
    }
}

struct ApplicationsSettingsView: View {
    @AppStorage("workingApps") private var workingApps = ""
    @State private var newApp = ""
    
    var appsList: [String] {
        workingApps.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Applications that indicate work:")
                .font(.headline)
            
            List {
                ForEach(appsList, id: \.self) { app in
                    Text(app)
                }
            }
            
            HStack {
                TextField("Add application", text: $newApp)
                Button("Add") {
                    if !newApp.isEmpty {
                        if workingApps.isEmpty {
                            workingApps = newApp
                        } else {
                            workingApps += ", \(newApp)"
                        }
                        newApp = ""
                    }
                }
            }
        }
        .padding()
    }
}

struct NotificationsSettingsView: View {
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("breakReminder") private var breakReminder = true
    @AppStorage("breakIntervalMinutes") private var breakIntervalMinutes = 60
    
    var body: some View {
        Form {
            Toggle("Show notifications", isOn: $showNotifications)
            
            Toggle("Break reminders", isOn: $breakReminder)
                .disabled(!showNotifications)
            
            HStack {
                Text("Remind every (minutes):")
                TextField("", value: $breakIntervalMinutes, format: .number)
                    .frame(width: 50)
                    .disabled(!breakReminder || !showNotifications)
            }
        }
        .padding()
    }
}
EOF

# Create AppStateManager
cat > "$PROJECT_NAME/ViewModels/AppStateManager.swift" << 'EOF'
//
//  AppStateManager.swift
//  WorkLifeBalance
//

import Foundation
import SwiftUI
import Combine

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
    @Published var currentState: WorkState = .idle
    @Published var workTime: TimeInterval = 0
    @Published var restTime: TimeInterval = 0
    @Published var idleTime: TimeInterval = 0
    
    private var stateTimer: Timer?
    private var activityMonitor: ActivityMonitor?
    private var databaseManager: DatabaseManager?
    
    var formattedWorkTime: String {
        formatTime(workTime)
    }
    
    var formattedRestTime: String {
        formatTime(restTime)
    }
    
    var formattedIdleTime: String {
        formatTime(idleTime)
    }
    
    init() {
        setupMonitoring()
        loadTodayData()
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
EOF

# Create ActivityMonitor
cat > "$PROJECT_NAME/Services/ActivityMonitor.swift" << 'EOF'
//
//  ActivityMonitor.swift
//  WorkLifeBalance
//

import Foundation
import CoreGraphics
import AppKit

class ActivityMonitor {
    private var lastEventTime: Date = Date()
    private var mouseLocation: CGPoint = .zero
    
    init() {
        setupEventMonitors()
    }
    
    private func setupEventMonitors() {
        // Monitor global mouse and keyboard events
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]) { event in
            self.lastEventTime = Date()
        }
        
        // Monitor local events (within our app)
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]) { event in
            self.lastEventTime = Date()
            return event
        }
    }
    
    func getIdleTime() -> TimeInterval {
        return Date().timeIntervalSince(lastEventTime)
    }
    
    func getCurrentActiveWindow() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }
    
    func getCurrentActiveProcess() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    func getMousePosition() -> CGPoint {
        return NSEvent.mouseLocation
    }
}
EOF

# Create DatabaseManager
cat > "$PROJECT_NAME/Services/DatabaseManager.swift" << 'EOF'
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
            let query = timeEntries
                .filter(date >= startOfDay)
                .order(timestamp.desc)
                .limit(1)
            
            if let entry = try db?.pluck(query) {
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
        
        return nil
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
EOF

# Create Info.plist
cat > "$PROJECT_NAME/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.vanboompow.WorkLifeBalance</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMainStoryboardFile</key>
    <string>Main</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "✅ Xcode project structure created successfully!"
echo ""
echo "Next steps:"
echo "1. Open the project in Xcode: open Package.swift"
echo "2. Build and run the project"
echo "3. The app will appear in the menu bar"
echo ""
echo "Project features implemented:"
echo "- Menu bar app with popover UI"
echo "- Work/Rest/Idle state tracking"
echo "- Auto-detection of work applications"
echo "- Time tracking with SQLite database"
echo "- Settings window for configuration"
echo "- Activity monitoring for idle detection"