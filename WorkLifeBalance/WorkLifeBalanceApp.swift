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
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover = NSPopover()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up menu bar icon
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Work Life Balance")
            button.action = #selector(togglePopover)
        }
        
        // Configure popover with shared AppStateManager
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(AppStateManager.shared)
        )
    }
    
    @objc func togglePopover() {
        if let button = statusBarItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}