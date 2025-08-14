//
//  TimeRingChart.swift
//  WorkLifeBalance
//

import SwiftUI
import Charts

struct TimeRingChart: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var animationProgress: CGFloat = 0
    
    // Chart dimensions
    private let chartSize: CGFloat = 200
    private let ringWidth: CGFloat = 12
    private let ringSpacing: CGFloat = 4
    
    var body: some View {
        ZStack {
            // Background rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        ringColor(for: index).opacity(0.1),
                        lineWidth: ringWidth
                    )
                    .frame(width: ringSize(for: index), height: ringSize(for: index))
            }
            
            // Progress rings
            TimeRing(
                progress: workProgress,
                color: .green,
                size: ringSize(for: 0),
                lineWidth: ringWidth,
                animationProgress: animationProgress
            )
            
            TimeRing(
                progress: restProgress,
                color: .blue,
                size: ringSize(for: 1),
                lineWidth: ringWidth,
                animationProgress: animationProgress
            )
            
            TimeRing(
                progress: idleProgress,
                color: .gray,
                size: ringSize(for: 2),
                lineWidth: ringWidth,
                animationProgress: animationProgress
            )
            
            // Center content
            VStack(spacing: 8) {
                // Current state indicator
                ZStack {
                    Circle()
                        .fill(appState.currentState.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .fill(appState.currentState.color)
                        .frame(width: 40, height: 40)
                        .scaleEffect(animationProgress)
                    
                    Image(systemName: currentStateIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.currentState)
                
                // Time display
                VStack(spacing: 2) {
                    Text(appState.currentState.description)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(appState.currentState.color)
                    
                    Text(currentStateTimeFormatted)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: chartSize, height: chartSize)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: appState.currentState) { _, _ in
            // Bounce animation when state changes
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                animationProgress = 0.8
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
                animationProgress = 1.0
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalTime: TimeInterval {
        let total = appState.workTime + appState.restTime + appState.idleTime
        return total > 0 ? total : 1 // Prevent division by zero
    }
    
    private var workProgress: CGFloat {
        CGFloat(appState.workTime / totalTime)
    }
    
    private var restProgress: CGFloat {
        CGFloat(appState.restTime / totalTime)
    }
    
    private var idleProgress: CGFloat {
        CGFloat(appState.idleTime / totalTime)
    }
    
    private var currentStateIcon: String {
        switch appState.currentState {
        case .working:
            return "desktopcomputer"
        case .resting:
            return "cup.and.saucer.fill"
        case .idle:
            return "moon.zzz.fill"
        }
    }
    
    private var currentStateTimeFormatted: String {
        switch appState.currentState {
        case .working:
            return appState.formattedWorkTime
        case .resting:
            return appState.formattedRestTime
        case .idle:
            return appState.formattedIdleTime
        }
    }
    
    // MARK: - Helper Functions
    
    private func ringSize(for index: Int) -> CGFloat {
        chartSize - CGFloat(index) * (ringWidth + ringSpacing) * 2
    }
    
    private func ringColor(for index: Int) -> Color {
        switch index {
        case 0: return .green
        case 1: return .blue
        case 2: return .gray
        default: return .gray
        }
    }
}

// MARK: - TimeRing Component

struct TimeRing: View {
    let progress: CGFloat
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    let animationProgress: CGFloat
    
    var body: some View {
        Circle()
            .trim(from: 0, to: progress * animationProgress)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.6),
                        color,
                        color.opacity(0.8)
                    ]),
                    center: .center,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(270)
                ),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
    }
}

// MARK: - Ring Legend Component

struct TimeRingLegend: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        HStack(spacing: 20) {
            LegendItem(
                color: .green,
                title: "Work",
                value: appState.formattedWorkTime,
                isActive: appState.currentState == .working
            )
            
            LegendItem(
                color: .blue,
                title: "Rest",
                value: appState.formattedRestTime,
                isActive: appState.currentState == .resting
            )
            
            LegendItem(
                color: .gray,
                title: "Idle",
                value: appState.formattedIdleTime,
                isActive: appState.currentState == .idle
            )
        }
    }
}

struct LegendItem: View {
    let color: Color
    let title: String
    let value: String
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isActive ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundColor(isActive ? color : .secondary)
            }
            
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .animation(.smooth, value: isActive)
    }
}

// MARK: - Compact Time Ring for smaller spaces

struct CompactTimeRing: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var animationProgress: CGFloat = 0
    
    let size: CGFloat
    
    init(size: CGFloat = 80) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 6)
            
            // Combined progress ring
            Circle()
                .trim(from: 0, to: combinedProgress * animationProgress)
                .stroke(
                    gradientForCurrentState,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Center icon
            Image(systemName: "timer")
                .font(.system(size: size * 0.3, weight: .medium))
                .foregroundColor(appState.currentState.color)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
    
    private var totalTime: TimeInterval {
        let total = appState.workTime + appState.restTime + appState.idleTime
        return total > 0 ? total : 1
    }
    
    private var combinedProgress: CGFloat {
        CGFloat((appState.workTime + appState.restTime) / totalTime)
    }
    
    private var gradientForCurrentState: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                appState.currentState.color.opacity(0.6),
                appState.currentState.color,
                appState.currentState.color.opacity(0.8)
            ]),
            center: .center
        )
    }
}

#Preview("TimeRingChart") {
    TimeRingChart()
        .environmentObject(AppStateManager.shared)
        .padding()
}

#Preview("TimeRingLegend") {
    VStack {
        TimeRingChart()
        TimeRingLegend()
    }
    .environmentObject(AppStateManager.shared)
    .padding()
}

#Preview("CompactTimeRing") {
    CompactTimeRing()
        .environmentObject(AppStateManager.shared)
        .padding()
}