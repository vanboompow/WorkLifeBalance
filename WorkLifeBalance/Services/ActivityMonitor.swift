//
//  ActivityMonitor.swift
//  WorkLifeBalance
//

import Foundation
import CoreGraphics
import AppKit

class ActivityMonitor {
    private var lastEventTime: Date = Date()
    private var mouseLocation: CGPoint = .zero
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    init() {
        setupEventMonitors()
    }
    
    deinit {
        // Clean up event monitors to prevent memory leaks
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupEventMonitors() {
        // Monitor global mouse and keyboard events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            self?.lastEventTime = Date()
        }
        
        // Monitor local events (within our app)
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            self?.lastEventTime = Date()
            return event
        }
    }
    
    func getIdleTime() -> TimeInterval {
        return Date().timeIntervalSince(lastEventTime)
    }
    
    func getCurrentActiveWindow() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }
    
    func getCurrentActiveProcess() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    func getMousePosition() -> CGPoint {
        return NSEvent.mouseLocation
    }
}