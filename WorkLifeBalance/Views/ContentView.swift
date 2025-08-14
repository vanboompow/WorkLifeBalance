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
        VStack(spacing: 15) {
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
            
            Divider()
            
            Button("Quit Work Life Balance") {
                // Save any pending data before quitting
                Task { @MainActor in
                    await appState.saveCurrentSession()
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
}

struct PopoverView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var showingDetails = false
    
    var body: some View {
        ZStack {
            // Glassmorphic background
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with current status
                    StatusPill()
                    
                    // Main time chart
                    VStack(spacing: 12) {
                        TimeRingChart()
                        
                        if showingDetails {
                            TimeRingLegend()
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                        
                        Button {
                            withAnimation(.smooth) {
                                showingDetails.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showingDetails ? "Hide Details" : "Show Details")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .rotationEffect(.degrees(showingDetails ? 180 : 0))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Quick stats cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        CompactStatsCard(
                            icon: "desktopcomputer",
                            title: "Work",
                            value: appState.formattedWorkTime,
                            color: .green,
                            isActive: appState.currentState == .working
                        )
                        
                        CompactStatsCard(
                            icon: "cup.and.saucer.fill",
                            title: "Rest",
                            value: appState.formattedRestTime,
                            color: .blue,
                            isActive: appState.currentState == .resting
                        )
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        PopoverActionButton(
                            icon: "play.fill",
                            title: "Work",
                            color: .green,
                            isEnabled: appState.currentState != .working
                        ) {
                            appState.startWork()
                        }
                        
                        PopoverActionButton(
                            icon: "pause.fill",
                            title: "Break",
                            color: .blue,
                            isEnabled: appState.currentState != .resting
                        ) {
                            appState.startRest()
                        }
                        
                        PopoverActionButton(
                            icon: "gearshape.fill",
                            title: "Settings",
                            color: .gray,
                            isEnabled: true
                        ) {
                            appState.showSettings()
                        }
                    }
                    
                    // Footer
                    HStack {
                        Button("Dashboard") {
                            // Open dashboard window
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Quit") {
                            Task { @MainActor in
                                await appState.saveCurrentSession()
                                NSApplication.shared.terminate(nil)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 350, height: 450)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Popover Components

struct StatusPill: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.currentState.color)
                .frame(width: 8, height: 8)
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: appState.currentState)
            
            Text(appState.currentState.description)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(appState.currentState.color)
            
            Text("•")
                .foregroundColor(.secondary)
            
            Text(currentStateTime)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(appState.currentState.color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(appState.currentState.color.opacity(0.2), lineWidth: 0.5)
                )
        )
        .animation(.smooth, value: appState.currentState)
    }
    
    private var currentStateTime: String {
        switch appState.currentState {
        case .working:
            return appState.formattedWorkTime
        case .resting:
            return appState.formattedRestTime
        case .idle:
            return appState.formattedIdleTime
        }
    }
}

struct CompactStatsCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isActive ? color : color.opacity(0.6))
                    .frame(width: 20, height: 20)
                
                Spacer()
                
                if isActive {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? color : .secondary)
                
                Text(value)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? color.opacity(0.08) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? color.opacity(0.2) : .clear, lineWidth: 0.5)
                )
        )
        .animation(.smooth, value: isActive)
    }
}

struct PopoverActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? color.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isEnabled ? color : .secondary)
                }
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }) {
            // Long press action if needed
        }
    }
}
