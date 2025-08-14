# WorkLifeBalance for macOS

A beautiful, native macOS productivity tracker that helps users monitor and optimize their work-life balance through automatic activity detection, elegant visualizations, and intelligent break reminders.

![WorkLifeBalance Overview](Assets/WorkLifeBalanceThumb.png)

## 🌟 Project Status

This is a **standalone macOS application** inspired by the original Windows version, completely rebuilt with:
- **SwiftUI** for beautiful, native UI
- **Swift 5.9+** with modern concurrency
- **Menu bar design** with quick popover access
- **Swift Charts** for stunning data visualizations
- **Native macOS integration** for seamless experience

### Design Philosophy

Inspired by successful apps like CodeEdit, Cork, and Reminders MenuBar, we follow:
- **Native Feel**: SF Symbols, vibrancy effects, and native controls
- **Minimalist Elegance**: Clean interfaces with thoughtful spacing
- **Smooth Animations**: Fluid transitions with spring physics
- **Adaptive Materials**: Modern glassmorphic design
- **Corner Concentricity**: Perfectly aligned control corners

## ✨ Features

### Core Functionality
- **🕐 Automatic Time Tracking**
  - Automatically detects work/rest/idle states
  - Tracks time spent in each state throughout the day
  - Persists data locally using SQLite

- **🖥️ Smart App Detection**
  - Automatically switches to "Working" when using configured apps
  - Default work apps: Xcode, Visual Studio Code, Terminal
  - Fully customizable app list in settings

- **💤 Idle Detection**
  - Monitors mouse and keyboard activity
  - Automatically switches to idle state after configurable timeout
  - Helps track actual productive time vs. away time

### User Interface
- **📊 Menu Bar Popover**
  - Quick access from the menu bar
  - Shows current status with colored indicator
  - Displays today's time breakdown
  - Manual work/rest controls

- **⚙️ Settings Window**
  - **General**: Auto-detect toggle, idle timeout, launch at login
  - **Applications**: Manage which apps indicate work
  - **Notifications**: Configure break reminders (coming soon)

## 🚀 Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building from source)

### Building from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/vanboompow/WorkLifeBalance.git
   cd WorkLifeBalance
   git checkout macos-port
   ```

2. **Open in Xcode**
   ```bash
   open Package.swift
   ```
   Or use Swift Package Manager:
   ```bash
   swift build
   swift run
   ```

3. **Grant Permissions**
   - On first run, grant Accessibility permissions in System Settings
   - Required for global event monitoring (idle detection)

### Pre-built Release
Coming soon - check the [Releases](https://github.com/vanboompow/WorkLifeBalance/releases) page

## 🎯 Usage

1. **Launch the app** - Look for the timer icon (⏱️) in your menu bar
2. **Click the icon** to open the popover and view your stats
3. **Configure work apps** in Settings > Applications
4. **Let it run** - The app will automatically track your work patterns

### Keyboard Shortcuts
- `Return` - Add application in settings
- `Cmd+Q` - Quit application (when popover is open)

## 🔒 Privacy & Security

This app requires the following permissions:
- **Accessibility Access**: For monitoring keyboard/mouse activity (idle detection)
  - Grant in System Settings > Privacy & Security > Accessibility

All data is stored locally on your Mac. No data is sent to external servers.

## 🛠️ Technical Architecture

### Technology Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Database**: SQLite.swift
- **Architecture**: MVVM with Combine
- **Package Manager**: Swift Package Manager

### Key Components
```
WorkLifeBalance/
├── ViewModels/
│   └── AppStateManager.swift    # Central state management
├── Views/
│   ├── ContentView.swift        # Main popover UI
│   └── SettingsView.swift       # Settings window
├── Services/
│   ├── ActivityMonitor.swift    # Mouse/keyboard monitoring
│   └── DatabaseManager.swift    # SQLite persistence
└── WorkLifeBalanceApp.swift     # App entry point
```

## ✅ Implementation Status

### Phase 1: Core Architecture ✅
**Completed Components**:
- ✅ **Data Models** - Complete type system with protocols and structs
- ✅ **PopoverView** - Beautiful 350x450px glassmorphic design  
- ✅ **MenuBarView** - Dynamic icon with state colors and progress ring
- ✅ **LaunchAtLoginManager** - Modern SMLoginItemSetEnabled implementation
- ✅ **NotificationManager** - UserNotifications framework integration

### Phase 2: Beautiful UI ✅
**Implemented Visualizations**:
- ✅ **DashboardWindow** - 900x600px window with tab navigation
- ✅ **TimeRingChart** - Apple Fitness-style circular progress
- ✅ **QuickStatsCard** - Glassmorphic cards with hover effects
- ✅ **Modern Design System** - Vibrancy, materials, and spring animations
- 🚧 **Analytics/History Tabs** - Placeholder UI ready for data integration

### Phase 3: Advanced Features ✅
**Export & Productivity**:
- ✅ **ExportView** - Complete export dialog with multiple formats
- ✅ **ExportManager** - CSV/JSON/PDF/HTML export functionality
- ✅ **ReportGenerator** - Professional PDF reports with charts
- ✅ **FocusModeIntegration** - macOS Focus mode awareness
- 🚧 **ForceWork/Pomodoro** - UI created, logic pending

### Phase 4: Modernization & Cleanup ✅
**Swift 6.0 & Cleanup**:
- ✅ **Windows Artifacts Removed** - 79 files deleted, pure macOS project
- ✅ **Swift 6.0 Migration** - Modern async/await and actors
- ✅ **Database Modernized** - Actor-isolated with async operations
- ✅ **Comprehensive Models** - 8 model files with Sendable conformance
- 🚧 **Compilation** - 93 concurrency fixes needed for Swift 6 strict mode

## 🎨 Design Specifications

### Menu Bar Design
```
Dynamic Icon Features:
- State color tint (green=work, blue=rest, gray=idle)
- Progress ring showing daily completion
- Optional time badge
- Right-click context menu
```

### Popover View (350x450px)
```
┌─────────────────────────────┐
│  [Animated State Pill]       │
│  ┌─────────────────────┐    │
│  │   Circular Chart    │    │
│  │    02:34:16         │    │
│  └─────────────────────┘    │
│                              │
│  [Work] [Rest] [Idle]        │  <- Glassmorphic cards
│                              │
│  [Settings] [Dashboard]      │  <- Action buttons
└─────────────────────────────┘
```

### Dashboard Window (900x600px)
```
┌────────────────────────────────────────┐
│        Today's Overview                │
│    [Beautiful Ring Chart]              │
│                                        │
│ [Overview | Apps | Analytics | History]│
│                                        │
│      Tab Content Area                  │
└────────────────────────────────────────┘
```

## 🏗️ Architecture

### Missing Views (Priority Order)
1. **PopoverView.swift** - CRITICAL! Main menu bar interface
2. **MenuBarView.swift** - Dynamic icon management
3. **TimeRingChart.swift** - Custom circular progress
4. **DashboardWindow.swift** - Main application window
5. **AnalyticsTab.swift** - Charts and statistics
6. **HistoryCalendarView.swift** - Activity heat map
7. **ForceWorkSheet.swift** - Manual override modal
8. **PomodoroTimer.swift** - Timer functionality
9. **ExportView.swift** - Data export options
10. **NotificationSettingsView.swift** - Alert configuration

### Database Schema
```sql
-- Core tables shared with Windows version
CREATE TABLE DayData (
    Id INTEGER PRIMARY KEY,
    Date TEXT NOT NULL,
    TotalWorkTime INTEGER,
    TotalRestTime INTEGER,
    TotalIdleTime INTEGER
);

CREATE TABLE ProcessActivityData (
    Id INTEGER PRIMARY KEY,
    DayDataId INTEGER,
    ProcessName TEXT,
    TimeSpent INTEGER,
    FOREIGN KEY(DayDataId) REFERENCES DayData(Id)
);

CREATE TABLE AppSettingsData (
    Id INTEGER PRIMARY KEY,
    AutoDetect INTEGER,
    IdleTimeout INTEGER,
    WorkApplications TEXT,
    LaunchAtStartup INTEGER,
    NotificationEnabled INTEGER,
    NotificationInterval INTEGER
);
```

## 🧪 Testing Strategy

### Unit Tests Required
- [ ] State management logic
- [ ] Time calculation accuracy
- [ ] Database operations
- [ ] Process detection
- [ ] Export functionality

### UI Tests Required
- [ ] Menu bar interactions
- [ ] Popover show/hide
- [ ] Settings changes
- [ ] Tab navigation
- [ ] Chart rendering

### Performance Targets
- Memory usage: < 50MB
- CPU idle: < 1%
- Animation FPS: 60fps
- Launch time: < 2 seconds
- State transition: < 100ms

## 🧹 Cleanup Tasks

### Windows Files to Remove
```
Files to delete:
- All *.cs files (C# source)
- All *.xaml files (WPF views)
- All *.csproj files (project files)
- WorkLifeBalance.sln (solution file)
- app.manifest (Windows manifest)
- appsettings.json (Windows config)

Directories to remove:
- /ViewModels (Windows-specific)
- /Views (WPF views)
- /Services (Windows services)
- /Converters (XAML converters)
- /Interfaces (C# interfaces)
- /Models (C# models)

Assets to evaluate:
- Keep shared images (PNG files)
- Remove Windows-specific icons
- Optimize remaining assets
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to your fork
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- Original Windows version by [@szr2001](https://github.com/szr2001)
- macOS port by [@vanboompow](https://github.com/vanboompow)
- Built with assistance from [Claude Code](https://claude.ai/code)

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/vanboompow/WorkLifeBalance/issues)
- **Original Project**: [Windows Version](https://github.com/szr2001/WorkLifeBalance)
- **Support Original Author**: [Buy Me a Coffee](https://buymeacoffee.com/roberbot)

---

**Note**: This is an unofficial port of the WorkLifeBalance application to macOS. For the original Windows version, please visit the [original repository](https://github.com/szr2001/WorkLifeBalance).