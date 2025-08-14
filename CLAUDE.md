# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WorkLifeBalance is a native macOS productivity application that automatically tracks work/rest time and helps users optimize their work-life balance through beautiful visualizations and intelligent break reminders. This is a **standalone macOS application** built from the ground up with modern Swift and SwiftUI.

## Technology Stack

- **Language**: Swift 5.9+ with modern concurrency
- **UI Framework**: SwiftUI with native macOS adaptations  
- **Architecture**: MVVM with Combine and @Observable
- **Database**: SQLite.swift with type-safe queries
- **Interface**: Menu bar app with elegant popover design
- **System Integration**: NSWorkspace, Accessibility APIs, Focus Mode
- **Requirements**: macOS 14.0 (Sonoma) or later

## Essential Commands

### Development Commands
```bash
# Open in Xcode
open Package.swift

# Build with Swift Package Manager
swift build

# Run the macOS app
swift run

# Run tests
swift test

# Build for release
swift build -c release

# Build for Xcode (generates .app bundle)
xcodebuild -scheme WorkLifeBalance -destination 'platform=macOS'
```

## Architecture Overview

### Core Features
1. **Automatic Time Tracking**
   - Detects work/rest/idle states
   - Configurable idle timeout (default: 5 minutes)
   - Persists data in local SQLite database

2. **Smart App Detection**
   - Monitors active macOS applications via NSWorkspace
   - Auto-switches to "Working" for configured apps
   - Customizable app list with bundle ID support

3. **State Management**
   - Three states: Working, Resting, Idle
   - Manual override capabilities
   - Background process monitoring

### Directory Structure

```
WorkLifeBalance-macOS/
├── Assets/                    # Images and sound resources
│   ├── *.png                 # UI icons and graphics
│   └── Sounds/               # Notification sounds
├── WorkLifeBalance/          # Swift source code
│   ├── WorkLifeBalanceApp.swift  # App entry point
│   ├── Info.plist            # macOS app configuration
│   ├── Models/               # Data models (Swift)
│   │   ├── DayStatistics.swift
│   │   ├── ProcessActivity.swift
│   │   ├── WorkSession.swift
│   │   └── UserPreferences.swift
│   ├── Views/                # SwiftUI views
│   │   ├── ContentView.swift
│   │   ├── MenuBarView.swift
│   │   ├── SettingsView.swift
│   │   └── DashboardWindow.swift
│   ├── ViewModels/           # MVVM ViewModels
│   │   └── AppStateManager.swift
│   ├── Services/             # Business logic services
│   │   ├── ActivityMonitor.swift
│   │   ├── DatabaseManager.swift
│   │   └── NotificationManager.swift
│   └── Utilities/            # Helper utilities
├── Package.swift             # Swift package manifest
├── Package.resolved          # Resolved dependencies
└── create_xcode_project.sh   # Build script
```

## Development Guidelines

### Code Conventions

#### Swift/SwiftUI Guidelines
- Follow Swift API Design Guidelines strictly
- Use SwiftUI and Combine for reactive UI programming
- Implement proper error handling with Result types
- Use `@MainActor` for all UI updates
- Support async/await for modern concurrency
- Adopt `@Observable` macro for state management
- Use structured concurrency with TaskGroup for parallel operations
- Implement proper accessibility support with SwiftUI modifiers

### Database Schema

The macOS app uses the following SQLite schema:

```sql
-- Main tracking table
CREATE TABLE DayData (
    Id INTEGER PRIMARY KEY,
    Date TEXT NOT NULL,
    TotalWorkTime INTEGER,
    TotalRestTime INTEGER,
    TotalIdleTime INTEGER
);

-- Process activity tracking
CREATE TABLE ProcessActivityData (
    Id INTEGER PRIMARY KEY,
    DayDataId INTEGER,
    ProcessName TEXT,
    TimeSpent INTEGER,
    FOREIGN KEY(DayDataId) REFERENCES DayData(Id)
);

-- Settings storage
CREATE TABLE AppSettingsData (
    Id INTEGER PRIMARY KEY,
    AutoDetect INTEGER,
    IdleTimeout INTEGER,
    WorkApplications TEXT,
    LaunchAtStartup INTEGER
);
```

### macOS-Specific Considerations

#### System Requirements
- Requires macOS 14.0 (Sonoma) or later
- Swift 5.9+ runtime (bundled with macOS)
- Xcode 15.0+ for development

#### System Integration
- Uses LaunchAgents for launch at login functionality
- Implements native menu bar app with SwiftUI popover
- Requires Accessibility permissions for global event monitoring
- Integrates with Focus Mode and Do Not Disturb
- Stores database in `~/Library/Application Support/WorkLifeBalance/`
- Uses Keychain for secure preference storage

#### Architecture Patterns
- MenuBarExtra for native menu bar integration
- NSPopover with SwiftUI hosting for the main interface  
- Combine for reactive data flow
- Actor isolation for thread-safe data operations

## Testing Approach

### Swift Testing
```bash
# Unit tests
swift test --filter WorkLifeBalanceTests.Unit

# Integration tests  
swift test --filter WorkLifeBalanceTests.Integration

# UI tests with Xcode
xcodebuild test -scheme WorkLifeBalance

# Performance tests
xcodebuild test -scheme WorkLifeBalance -testPlan PerformanceTests
```

### Test Categories
- **Unit Tests**: Model logic, data transformations, utilities
- **Integration Tests**: Database operations, service interactions
- **UI Tests**: SwiftUI view rendering, user interactions
- **Performance Tests**: Memory usage, CPU efficiency, animation smoothness

## Security & Privacy

### Required Permissions

#### macOS Permissions
- **Accessibility API access** for global keyboard/mouse event monitoring
- **File system access** for database operations in Application Support
- **Login Items access** for launch at login functionality
- **Notifications** for break reminders and state changes

### Data Privacy
- All data stored locally, no network communication
- No telemetry or analytics
- Database encrypted at rest (platform-dependent)
- No personal information collected

## Common Issues & Solutions

### macOS Troubleshooting

1. **Accessibility permission denied**
   - Grant in System Settings > Privacy & Security > Accessibility
   - Restart app after granting permission
   - Check that permission is enabled for the correct app bundle

2. **Menu bar icon not appearing**
   - Check `LSUIElement` in Info.plist is set to true
   - Verify SwiftUI App lifecycle configuration
   - Ensure MenuBarExtra is properly initialized in App.swift

3. **Database access errors**
   - Check write permissions in ~/Library/Application Support/
   - Verify SQLite.swift dependency is properly linked
   - Ensure database directory creation on first launch

4. **Popover not displaying**
   - Verify AppStateManager is properly injected as environment object
   - Check SwiftUI view hierarchy for missing views
   - Ensure popover content view is defined and accessible

5. **Performance issues**
   - Check for excessive UI updates in SwiftUI views
   - Verify database operations are running on background queues
   - Monitor for memory leaks in Combine subscriptions

## Build & Deployment

### macOS Deployment
```bash
# Create app bundle
swift build -c release
./create_xcode_project.sh  # Custom script to generate .app

# Build with Xcode for distribution
xcodebuild -scheme WorkLifeBalance -configuration Release \
  -destination 'platform=macOS' \
  -archivePath WorkLifeBalance.xcarchive archive

# Code signing (requires Developer ID)
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  WorkLifeBalance.app

# Notarization (requires Apple ID)
xcrun notarytool submit WorkLifeBalance.app \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "@keychain:notarization-password" \
  --wait

# Create DMG for distribution
hdiutil create -volname "WorkLifeBalance" \
  -srcfolder WorkLifeBalance.app \
  -ov -format UDZO WorkLifeBalance.dmg
```

## Handling Missing Dependencies

When encountering missing tools or packages:

1. **First, try to install it** - Use the appropriate package manager (brew, swift, xcode-select, etc.)
2. **If installation fails** (e.g., requires sudo access):
   - Ask the user to install it manually
   - Provide clear installation instructions
   - Wait for user confirmation before proceeding
3. **Only look for alternatives** after installation attempts fail
4. **Never skip to workarounds** without first attempting proper installation

Example: If Xcode Command Line Tools are missing, suggest `xcode-select --install`

## Features Status

### Currently Implemented ✅
- Automatic work/rest/idle state detection
- Time tracking with SQLite persistence
- Smart app detection with NSWorkspace
- Menu bar interface with popover
- Customizable work applications list
- Basic settings management

### macOS-Specific Features 🍎
- Native SwiftUI interface with glassmorphism
- MenuBarExtra integration for system-level access
- Accessibility API integration for event monitoring
- Focus Mode and Do Not Disturb awareness
- Launch at Login via LaunchAgents
- Native macOS notifications

### Planned Features 📋
- Advanced analytics dashboard with Swift Charts
- Beautiful ring charts like Apple Fitness
- Calendar heat map for historical data
- Pomodoro timer integration
- Break reminder system
- Export functionality (CSV, JSON, PDF)
- Force work mode with manual override
- Sound notification support

## 🤖 Agent Orchestration Guide

### Phase 1: Architecture Setup (Days 1-2)
**Lead Agent: missing-types-architect**
- Analyze current Swift codebase for undefined types
- Create missing data models and protocols
- Define interfaces for new views
```swift
// Priority types to create:
protocol TimeTrackable
struct DayStatistics
struct ProcessActivity
enum NotificationType
```

**Support Agent: import-namespace-resolver**
- Fix module import issues
- Resolve namespace conflicts
- Add missing framework imports

### Phase 2: Core Implementation (Days 3-7)
**Lead Agent: general-purpose**
Critical tasks in order:
1. **Fix PopoverView.swift** (CRITICAL - app crashes without it!)
2. Implement MenuBarView with dynamic icon
3. Create TimeRingChart custom view
4. Build DashboardWindow with tabs
5. Add Swift Charts integration

### Phase 3: Features (Days 8-12)
**Lead Agent: export-module-specialist**
- CSV/JSON export functionality
- PDF report generation
- Data migration from Windows

**Support Agent: search-module-architect**
- App search functionality
- Analytics queries
- Pattern recognition

### Phase 4: Modern Swift (Days 13-15)
**Lead Agent: api-migration-specialist**
- Update to Swift 6 concurrency
- Migrate deprecated APIs
- Implement @Observable macro
- Add async/await throughout

### Phase 5: Testing (Days 16-18)
**Lead Agent: build-verification-orchestrator**
- Run comprehensive build verification
- Execute all test suites
- Verify performance targets
- Check memory leaks

### Phase 6: Cleanup (Days 19-20)
**Lead Agent: type-consolidation-specialist**
- Remove ALL Windows artifacts
- Consolidate duplicate code
- Optimize assets
- Final code review

## 🎨 Beautiful macOS Design Specifications

### Design System
```swift
// Colors (Adaptive)
extension Color {
    static let workState = Color.green
    static let restState = Color.blue
    static let idleState = Color.gray
    static let cardBackground = Color(NSColor.secondarySystemFill)
    static let glassMaterial = Material.hudWindow
}

// Typography
extension Font {
    static let dashboardTitle = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    static let statValue = Font.system(.title2, design: .monospaced).weight(.medium)
    static let statLabel = Font.system(.caption).weight(.light)
}

// Spacing
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// Animation
extension Animation {
    static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let quick = Animation.easeInOut(duration: 0.3)
    static let interactive = Animation.interactiveSpring()
}
```

### Menu Bar Icon Specifications
```swift
// Dynamic icon with state indication
class MenuBarIconManager {
    // Icon: SF Symbol "timer"
    // Size: 22x22px (16px icon centered)
    // Features:
    // - Color tint based on state
    // - Optional progress ring
    // - Badge with time counter
    // - Smooth transitions
}
```

### Popover Design (350x450px)
```swift
struct PopoverView: View {
    // Material: .hudWindow for vibrancy
    // Corner radius: 12px
    // Padding: 16px
    // Shadow: 20% opacity, 8px blur
    
    // Components:
    // 1. State pill with animation
    // 2. Circular time chart (200x200)
    // 3. Three stat cards (glassmorphic)
    // 4. Action buttons (SF Symbols)
}
```

### Dashboard Window (900x600px)
```swift
struct DashboardWindow: View {
    // Window style: .hiddenTitleBar
    // Background: .windowBackground
    // Tab navigation: native macOS style
    
    // Tabs:
    // - Overview: Hero chart + stats
    // - Apps: Process list management
    // - Analytics: Swift Charts graphs
    // - History: Calendar heat map
}
```

## 📋 Critical Missing Components

### Priority 1 (MUST FIX IMMEDIATELY)
```swift
// PopoverView.swift - App crashes without this!
struct PopoverView: View {
    @EnvironmentObject var appState: AppStateManager
    // Implementation required
}
```

### Priority 2 (Core Features)
- MenuBarView.swift - Dynamic icon
- TimeRingChart.swift - Circular progress
- DashboardWindow.swift - Main window
- NotificationManager.swift - Alerts

### Priority 3 (Enhancements)
- AnalyticsTab.swift - Charts
- HistoryCalendarView.swift - Heat map
- ForceWorkSheet.swift - Override
- PomodoroTimer.swift - Timer mode
- ExportView.swift - Data export

## 🧹 Cleanup Status

### Completed Cleanup ✅
All Windows artifacts have been successfully removed:
- All C# source files (*.cs) deleted
- All XAML files (*.xaml) deleted  
- Windows project files (*.csproj, *.sln) deleted
- Windows configuration (app.manifest, appsettings.json) deleted
- Empty Windows directories removed
- Windows-specific assets (*.ico) removed

### Remaining Assets
- PNG images: Retained for macOS use (can be used in SwiftUI)
- Sound files: Retained for notification system
- Shared resources: Optimized for retina displays

## 🎯 Success Metrics

- **Stability**: Zero crashes, no memory leaks
- **Performance**: <50MB RAM, <1% CPU idle
- **Animations**: Consistent 60fps
- **Launch**: <2 second startup
- **Transitions**: <100ms state changes
- **Test Coverage**: >80% code coverage
- **Code Quality**: 100% Swift/SwiftUI

## Important Notes

- This is a **standalone macOS-only project** - all Windows code has been removed
- Built with modern Swift 5.9+ and SwiftUI for macOS 14.0+
- Follows Apple Human Interface Guidelines for native macOS experience
- Uses latest SwiftUI features including @Observable and structured concurrency
- No cross-platform compatibility - focused purely on macOS excellence

## Documentation References

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [Menu Bar Apps Guide](https://developer.apple.com/documentation/swiftui/menubarextra)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)