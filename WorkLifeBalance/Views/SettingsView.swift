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
    @AppStorage("workingApps") private var workingApps = "Xcode,Visual Studio Code,Terminal"
    @State private var newApp = ""
    @State private var apps: [String] = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Applications that indicate work:")
                .font(.headline)
                .padding(.top)
            
            List {
                ForEach(apps, id: \.self) { app in
                    HStack {
                        Text(app)
                        Spacer()
                        Button(action: {
                            removeApp(app)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 200)
            
            HStack {
                TextField("Add application name", text: $newApp)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        addApp()
                    }
                
                Button("Add") {
                    addApp()
                }
                .disabled(newApp.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .onAppear {
            loadApps()
            // Focus the text field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func loadApps() {
        apps = workingApps.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    private func addApp() {
        guard !newApp.isEmpty else { return }
        let trimmedApp = newApp.trimmingCharacters(in: .whitespaces)
        
        if !apps.contains(trimmedApp) {
            apps.append(trimmedApp)
            saveApps()
        }
        newApp = ""
        // Keep focus on text field after adding
        isTextFieldFocused = true
    }
    
    private func removeApp(_ app: String) {
        apps.removeAll { $0 == app }
        saveApps()
    }
    
    private func saveApps() {
        workingApps = apps.joined(separator: ",")
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
