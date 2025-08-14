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
    @StateObject private var appState = AppStateManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Work Life Balance") {
                    // Save data before quitting
                    Task {
                        await AppStateManager.shared.saveCurrentSession()
                        NSApplication.shared.terminate(nil)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover = NSPopover()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up menu bar icon
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Work Life Balance")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Configure popover with shared AppStateManager
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(AppStateManager.shared)
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Save any pending data before app terminates
        Task {
            await AppStateManager.shared.saveCurrentSession()
        }
    }
    
    @objc func togglePopover() {
        guard let button = statusBarItem?.button else { return }
        
        // Check if it's a right-click (for context menu)
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu(for: button)
        } else {
            // Left click - toggle popover
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open Work Life Balance", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Work Life Balance", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusBarItem?.menu = menu
        button.performClick(nil)
        statusBarItem?.menu = nil // Clear menu after showing to restore normal click behavior
    }
    
    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func openSettings() {
        Task {
            await AppStateManager.shared.showSettings()
        }
    }
    
    @objc func quitApp() {
        Task {
            await AppStateManager.shared.saveCurrentSession()
            NSApplication.shared.terminate(nil)
        }
    }
}