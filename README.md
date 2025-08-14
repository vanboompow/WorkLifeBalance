# WorkLifeBalance for macOS

A native macOS port of the WorkLifeBalance productivity application, designed to help users monitor and optimize their time usage through automatic work/rest detection and detailed activity tracking.

![WorkLifeBalance Overview](Assets/WorkLifeBalanceThumb.png)

## 🍎 macOS Port Status

This is a **native macOS implementation** of the original Windows WPF application, built with:
- **SwiftUI** for the user interface
- **Swift 5.9+** for modern, safe code
- **Menu bar app** design (runs in system tray)
- **Native macOS APIs** for system integration

### Platform Differences

| Feature | Windows (Original) | macOS (This Port) |
|---------|-------------------|-------------------|
| UI Framework | WPF | SwiftUI |
| System Integration | Windows P/Invoke | NSWorkspace, CoreGraphics |
| Database | SQLite with Dapper | SQLite.swift |
| Tray/Menu Bar | System Tray | Menu Bar |
| Architecture | .NET 8.0 | Swift/SwiftUI MVVM |

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

## 🐛 Known Issues

1. **Launch at Login** - Not yet implemented
2. **Notifications** - Break reminders coming soon
3. **Accessibility Permissions** - Must be granted manually on first run

## 📊 Comparison with Original

### Features Implemented ✅
- [x] Automatic work/rest detection
- [x] Time tracking and persistence
- [x] Customizable work applications
- [x] Idle detection
- [x] Menu bar interface
- [x] Settings window

### Features In Progress 🚧
- [ ] Launch at login
- [ ] Break notifications
- [ ] Monthly comparison charts
- [ ] Pomodoro timer integration
- [ ] Advanced detection modes

### Features Not Yet Ported ❌
- [ ] Force work mode
- [ ] Detailed productivity analytics
- [ ] Export functionality
- [ ] Custom states beyond work/rest/idle

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