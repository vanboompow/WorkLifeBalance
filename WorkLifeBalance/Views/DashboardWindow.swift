//
//  DashboardWindow.swift
//  WorkLifeBalance
//

import SwiftUI
import Charts

struct DashboardWindow: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTab: DashboardTab = .overview
    @State private var window: NSWindow?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            DashboardSidebar(selectedTab: $selectedTab)
                .frame(minWidth: 200, maxWidth: 250)
                .background(.regularMaterial)
        } detail: {
            // Main content area
            DashboardContent(selectedTab: selectedTab)
                .background(.background)
        }
        .frame(width: 900, height: 600)
        .onAppear {
            setupWindow()
        }
    }
    
    private func setupWindow() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.contentView?.subviews.contains { $0 is NSHostingView<DashboardWindow> } ?? false }) {
                self.window = window
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
                window.title = "Work Life Balance Dashboard"
                window.subtitle = "Your productivity overview"
            }
        }
    }
}

// MARK: - Dashboard Tabs

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case apps = "Apps"
    case analytics = "Analytics"
    case history = "History"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .overview: return "chart.pie.fill"
        case .apps: return "app.badge.fill"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .history: return "calendar"
        }
    }
    
    var description: String {
        switch self {
        case .overview: return "Daily summary and current status"
        case .apps: return "Application usage and settings"
        case .analytics: return "Detailed charts and trends"
        case .history: return "Historical data and calendar view"
        }
    }
}

// MARK: - Sidebar

struct DashboardSidebar: View {
    @Binding var selectedTab: DashboardTab
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundColor(appState.currentState.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Work Life Balance")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Dashboard")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Current status pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.currentState.color)
                        .frame(width: 8, height: 8)
                    
                    Text(appState.currentState.description)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(appState.currentState.color.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .padding(.horizontal, 12)
            
            // Navigation
            VStack(spacing: 2) {
                ForEach(DashboardTab.allCases) { tab in
                    SidebarItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Spacer()
            
            // Footer actions
            VStack(spacing: 8) {
                Divider()
                
                Button {
                    appState.showSettings()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                        Spacer()
                    }
                }
                .buttonStyle(SidebarButtonStyle())
                
                Button {
                    // Export functionality
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Data")
                        Spacer()
                    }
                }
                .buttonStyle(SidebarButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }
}

struct SidebarItem: View {
    let tab: DashboardTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    if !isSelected {
                        Text(tab.description)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.secondary.opacity(0.1) : Color.clear)
            )
    }
}

// MARK: - Main Content

struct DashboardContent: View {
    let selectedTab: DashboardTab
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        Group {
            switch selectedTab {
            case .overview:
                OverviewTab()
            case .apps:
                AppsTab()
            case .analytics:
                AnalyticsTab()
            case .history:
                HistoryTab()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Tab Views

struct OverviewTab: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Overview")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.semibold)
                    
                    Text(Date(), style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Main chart and stats
                HStack(alignment: .top, spacing: 24) {
                    // Time ring chart
                    VStack(spacing: 16) {
                        TimeRingChart()
                        TimeRingLegend()
                    }
                    .frame(width: 250)
                    
                    // Quick stats grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        QuickStatsCard(
                            icon: "desktopcomputer",
                            title: "Work Time",
                            value: appState.formattedWorkTime,
                            color: .green
                        )
                        
                        QuickStatsCard(
                            icon: "cup.and.saucer.fill",
                            title: "Rest Time",
                            value: appState.formattedRestTime,
                            color: .blue
                        )
                        
                        QuickStatsCard(
                            icon: "moon.zzz.fill",
                            title: "Idle Time",
                            value: appState.formattedIdleTime,
                            color: .gray
                        )
                        
                        QuickStatsCard(
                            icon: "clock.fill",
                            title: "Total Time",
                            value: totalTimeFormatted,
                            color: .orange
                        )
                    }
                }
                
                // Quick actions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Actions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        ActionButton(
                            title: "Start Working",
                            icon: "play.fill",
                            color: .green,
                            isEnabled: appState.currentState != .working
                        ) {
                            appState.startWork()
                        }
                        
                        ActionButton(
                            title: "Take Break",
                            icon: "pause.fill",
                            color: .blue,
                            isEnabled: appState.currentState != .resting
                        ) {
                            appState.startRest()
                        }
                        
                        ActionButton(
                            title: "Settings",
                            icon: "gearshape.fill",
                            color: .gray,
                            isEnabled: true
                        ) {
                            appState.showSettings()
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var totalTimeFormatted: String {
        let total = appState.workTime + appState.restTime + appState.idleTime
        return formatTime(total)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? color.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .foregroundColor(isEnabled ? color : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// Placeholder tabs - these would be implemented with more detailed views
struct AppsTab: View {
    var body: some View {
        VStack {
            Text("Apps")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("Application usage and management")
                .foregroundColor(.secondary)
        }
    }
}

struct AnalyticsTab: View {
    var body: some View {
        VStack {
            Text("Analytics")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("Detailed charts and trends")
                .foregroundColor(.secondary)
        }
    }
}

struct HistoryTab: View {
    var body: some View {
        VStack {
            Text("History")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("Historical data and calendar view")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    DashboardWindow()
        .environmentObject(AppStateManager.shared)
}