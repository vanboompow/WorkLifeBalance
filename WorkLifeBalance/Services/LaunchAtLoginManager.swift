//
//  LaunchAtLoginManager.swift
//  WorkLifeBalance
//

import Foundation
import ServiceManagement
import OSLog

// MARK: - Launch at Login Errors
enum LaunchAtLoginError: Error, LocalizedError {
    case registrationFailed(String)
    case unregistrationFailed(String)
    case statusQueryFailed(String)
    case unsupportedOS(String)
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed(let message):
            return "Failed to register launch at login: \(message)"
        case .unregistrationFailed(let message):
            return "Failed to unregister launch at login: \(message)"
        case .statusQueryFailed(let message):
            return "Failed to query launch at login status: \(message)"
        case .unsupportedOS(let message):
            return "Unsupported macOS version: \(message)"
        }
    }
}

/// Modern launch at login manager using the latest ServiceManagement APIs
@MainActor
final class LaunchAtLoginManager: ObservableObject, Sendable {
    
    // MARK: - Published Properties
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "WorkLifeBalance", category: "LaunchAtLogin")
    private let userDefaults = UserDefaults.standard
    private let launchAtLoginKey = "LaunchAtLoginEnabled"
    
    // MARK: - Singleton
    static let shared = LaunchAtLoginManager()
    
    nonisolated init() {
        Task { @MainActor in
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        logger.info("Initializing LaunchAtLoginManager")
        
        // Load saved preference
        isEnabled = userDefaults.bool(forKey: launchAtLoginKey)
        
        // Verify actual status with the system
        await updateStatus()
        
        logger.info("LaunchAtLoginManager initialized - Status: \(isEnabled)")
    }
    
    // MARK: - Public API
    
    /// Enable or disable launch at login
    func setEnabled(_ enabled: Bool) async throws {
        logger.info("Setting launch at login: \(enabled)")
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if #available(macOS 13.0, *) {
                try await setEnabledModern(enabled)
            } else {
                try setEnabledLegacy(enabled)
            }
            
            // Update our state
            isEnabled = enabled
            userDefaults.set(enabled, forKey: launchAtLoginKey)
            
            logger.info("Successfully \(enabled ? "enabled" : "disabled") launch at login")
            
        } catch {
            logger.error("Failed to set launch at login: \(error.localizedDescription)")
            
            // Revert to actual system state
            await updateStatus()
            throw error
        }
    }
    
    /// Toggle launch at login state
    func toggle() async throws {
        try await setEnabled(!isEnabled)
    }
    
    /// Refresh status from the system
    func updateStatus() async {
        logger.debug("Updating launch at login status")
        
        let actualStatus: Bool
        
        if #available(macOS 13.0, *) {
            actualStatus = await getStatusModern()
        } else {
            actualStatus = getStatusLegacy()
        }
        
        if actualStatus != isEnabled {
            logger.warning("Launch at login status mismatch - updating from system")
            isEnabled = actualStatus
            userDefaults.set(actualStatus, forKey: launchAtLoginKey)
        }
        
        logger.debug("Launch at login status updated: \(isEnabled)")
    }
    
    // MARK: - Modern Implementation (macOS 13+)
    
    @available(macOS 13.0, *)
    private func setEnabledModern(_ enabled: Bool) async throws {
        do {
            if enabled {
                try await SMAppService.mainApp.register()
                logger.info("Registered app for launch at login using modern API")
            } else {
                try await SMAppService.mainApp.unregister()
                logger.info("Unregistered app from launch at login using modern API")
            }
        } catch {
            logger.error("Modern launch at login operation failed: \(error.localizedDescription)")
            
            if enabled {
                throw LaunchAtLoginError.registrationFailed(error.localizedDescription)
            } else {
                throw LaunchAtLoginError.unregistrationFailed(error.localizedDescription)
            }
        }
    }
    
    @available(macOS 13.0, *)
    private func getStatusModern() async -> Bool {
        do {
            let status = await SMAppService.mainApp.status
            
            switch status {
            case .enabled:
                return true
            case .requiresApproval:
                logger.warning("Launch at login requires user approval")
                return false
            case .notRegistered:
                return false
            case .notFound:
                logger.error("App service not found")
                return false
            @unknown default:
                logger.warning("Unknown launch at login status: \(status)")
                return false
            }
        }
    }
    
    // MARK: - Legacy Implementation (macOS 12 and earlier)
    
    private func setEnabledLegacy(_ enabled: Bool) throws {
        // For macOS 12 and earlier, we need to use the deprecated SMLoginItemSetEnabled
        // This is still the recommended approach for older systems
        
        guard let bundleID = Bundle.main.bundleIdentifier else {
            throw LaunchAtLoginError.registrationFailed("Unable to get bundle identifier")
        }
        
        #if canImport(ServiceManagement)
        // Use the legacy SMLoginItemSetEnabled for older macOS versions
        let success = SMLoginItemSetEnabled(bundleID as CFString, enabled)
        
        if !success {
            let errorMessage = enabled ? "registration" : "unregistration"
            logger.error("Legacy launch at login \(errorMessage) failed")
            
            if enabled {
                throw LaunchAtLoginError.registrationFailed("SMLoginItemSetEnabled failed")
            } else {
                throw LaunchAtLoginError.unregistrationFailed("SMLoginItemSetEnabled failed")
            }
        }
        
        logger.info("Successfully \(enabled ? "enabled" : "disabled") launch at login using legacy API")
        #else
        throw LaunchAtLoginError.unsupportedOS("ServiceManagement framework not available")
        #endif
    }
    
    private func getStatusLegacy() -> Bool {
        // For legacy systems, we rely on our stored preference since there's no reliable
        // way to query the actual system status with the old APIs
        return userDefaults.bool(forKey: launchAtLoginKey)
    }
    
    // MARK: - Utility Methods
    
    /// Check if the current macOS version supports modern launch at login APIs
    var supportsModernAPI: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
    
    /// Get a user-friendly status description
    var statusDescription: String {
        if isLoading {
            return "Updating..."
        }
        
        if #available(macOS 13.0, *) {
            return isEnabled ? "Enabled" : "Disabled"
        } else {
            return isEnabled ? "Enabled (Legacy)" : "Disabled"
        }
    }
    
    /// Get detailed information about the launch at login configuration
    func getDetailedStatus() async -> LaunchAtLoginStatus {
        await updateStatus()
        
        return LaunchAtLoginStatus(
            isEnabled: isEnabled,
            isLoading: isLoading,
            usesModernAPI: supportsModernAPI,
            lastUpdated: Date()
        )
    }
}

// MARK: - Launch at Login Status
struct LaunchAtLoginStatus: Sendable {
    let isEnabled: Bool
    let isLoading: Bool
    let usesModernAPI: Bool
    let lastUpdated: Date
    
    var description: String {
        let apiType = usesModernAPI ? "Modern" : "Legacy"
        let status = isEnabled ? "Enabled" : "Disabled"
        return "\(status) (\(apiType) API)"
    }
}

// MARK: - Extension for SwiftUI Integration
extension LaunchAtLoginManager {
    
    /// Convenience method for SwiftUI Toggle binding
    func createBinding() -> Binding<Bool> {
        Binding(
            get: { self.isEnabled },
            set: { enabled in
                Task {
                    try? await self.setEnabled(enabled)
                }
            }
        )
    }
}

// MARK: - Binding Import for SwiftUI
import SwiftUI

extension LaunchAtLoginManager {
    /// SwiftUI binding for toggle controls
    var enabledBinding: Binding<Bool> {
        Binding(
            get: { self.isEnabled },
            set: { enabled in
                Task { @MainActor in
                    do {
                        try await self.setEnabled(enabled)
                    } catch {
                        logger.error("Failed to update launch at login from binding: \(error.localizedDescription)")
                    }
                }
            }
        )
    }
}