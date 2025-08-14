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
                appState.showSettings()
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
