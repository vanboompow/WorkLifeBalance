//
//  QuickStatsCard.swift
//  WorkLifeBalance
//

import SwiftUI

struct QuickStatsCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let subtitle: String?
    let trend: TrendDirection?
    
    @State private var isHovered = false
    @State private var animateValue = false
    
    init(
        icon: String,
        title: String,
        value: String,
        color: Color,
        subtitle: String? = nil,
        trend: TrendDirection? = nil
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.color = color
        self.subtitle = subtitle
        self.trend = trend
    }
    
    var body: some View {
        ZStack {
            // Glassmorphic background
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and trend
                HStack {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    // Trend indicator
                    if let trend = trend {
                        TrendIndicator(direction: trend, color: color)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    // Value
                    Text(value)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .scaleEffect(animateValue ? 1.05 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animateValue)
                    
                    // Subtitle
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(Color.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(16)
        }
        .frame(height: 120)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            // Animate value on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateValue = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateValue = false
            }
        }
        .onChange(of: value) { _, _ in
            // Animate when value changes
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                animateValue = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    animateValue = false
                }
            }
        }
    }
}

// MARK: - Trend Direction

enum TrendDirection {
    case up, down, stable
    
    var systemImage: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

struct TrendIndicator: View {
    let direction: TrendDirection
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(direction.color.opacity(0.15))
                .frame(width: 24, height: 24)
            
            Image(systemName: direction.systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(direction.color)
        }
    }
}

// MARK: - Specialized Card Variants

struct WorkStatsCard: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        QuickStatsCard(
            icon: "desktopcomputer",
            title: "Work Time",
            value: appState.formattedWorkTime,
            color: .green,
            subtitle: "Today's focus time",
            trend: workTrend
        )
    }
    
    private var workTrend: TrendDirection {
        // In a real app, this would compare to previous day/week
        if appState.workTime > appState.restTime {
            return .up
        } else if appState.workTime < appState.restTime {
            return .down
        } else {
            return .stable
        }
    }
}

struct RestStatsCard: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        QuickStatsCard(
            icon: "cup.and.saucer.fill",
            title: "Rest Time",
            value: appState.formattedRestTime,
            color: .blue,
            subtitle: "Recovery time",
            trend: restTrend
        )
    }
    
    private var restTrend: TrendDirection {
        if appState.restTime > 3600 { // More than 1 hour
            return .up
        } else if appState.restTime < 1800 { // Less than 30 minutes
            return .down
        } else {
            return .stable
        }
    }
}

struct ProductivityCard: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        QuickStatsCard(
            icon: "chart.line.uptrend.xyaxis",
            title: "Productivity",
            value: productivityScore,
            color: productivityColor,
            subtitle: productivityDescription
        )
    }
    
    private var totalActiveTime: TimeInterval {
        appState.workTime + appState.restTime
    }
    
    private var totalTime: TimeInterval {
        totalActiveTime + appState.idleTime
    }
    
    private var productivity: Double {
        guard totalTime > 0 else { return 0 }
        return totalActiveTime / totalTime
    }
    
    private var productivityScore: String {
        String(format: "%.0f%%", productivity * 100)
    }
    
    private var productivityColor: Color {
        if productivity > 0.8 {
            return .green
        } else if productivity > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var productivityDescription: String {
        if productivity > 0.8 {
            return "Excellent focus"
        } else if productivity > 0.6 {
            return "Good balance"
        } else {
            return "Room for improvement"
        }
    }
}

struct StreakCard: View {
    let streakDays: Int
    
    init(streakDays: Int = 5) {
        self.streakDays = streakDays
    }
    
    var body: some View {
        QuickStatsCard(
            icon: "flame.fill",
            title: "Streak",
            value: "\(streakDays) days",
            color: .orange,
            subtitle: "Keep it up!",
            trend: .up
        )
    }
}

// MARK: - Large Stats Card

struct LargeStatsCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let description: String
    let progress: Double
    
    var body: some View {
        ZStack {
            // Glassmorphic background
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(value)
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(color)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [color.opacity(0.7), color],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 8)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(24)
        }
        .frame(height: 180)
    }
}

#Preview("QuickStatsCard") {
    HStack {
        QuickStatsCard(
            icon: "desktopcomputer",
            title: "Work Time",
            value: "4h 32m",
            color: .green,
            subtitle: "Today's focus time",
            trend: .up
        )
        
        QuickStatsCard(
            icon: "cup.and.saucer.fill",
            title: "Rest Time",
            value: "1h 15m",
            color: .blue,
            subtitle: "Recovery time",
            trend: .stable
        )
    }
    .padding()
}

#Preview("Specialized Cards") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2)) {
        WorkStatsCard()
        RestStatsCard()
        ProductivityCard()
        StreakCard()
    }
    .environmentObject(AppStateManager.shared)
    .padding()
}

#Preview("Large Stats Card") {
    LargeStatsCard(
        icon: "timer.circle.fill",
        title: "Total Time",
        value: "8h 45m",
        color: .purple,
        description: "Daily activity summary",
        progress: 0.75
    )
    .padding()
}