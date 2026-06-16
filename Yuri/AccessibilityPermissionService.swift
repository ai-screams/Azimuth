//
//  AccessibilityPermissionService.swift
//  Yuri
//
//  Created by Codex on 3/31/26.
//

import ApplicationServices
import Cocoa

enum AccessibilityPermissionStatus {
    case granted
    case required

    var isTrusted: Bool {
        self == .granted
    }

    var menuTitle: String {
        switch self {
        case .granted:
            "Accessibility Access: Granted"
        case .required:
            "Accessibility Access Required"
        }
    }

    var settingsStatusText: String {
        switch self {
        case .granted:
            "Yuri can control other app windows."
        case .required:
            "Yuri cannot control other app windows yet."
        }
    }

    var settingsDetailText: String {
        switch self {
        case .granted:
            "Accessibility access is enabled. You can continue with command wiring and window control."
        case .required:
            "Enable Accessibility access for Yuri in System Settings > Privacy & Security > Accessibility."
        }
    }
}

enum AccessibilityPermissionService {
    private static let settingsURLs = [
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security"
    ].compactMap(URL.init(string:))

    static func currentStatus() -> AccessibilityPermissionStatus {
        AXIsProcessTrusted() ? .granted : .required
    }

    @discardableResult
    static func requestPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func openSystemSettings() -> Bool {
        let workspace = NSWorkspace.shared

        for url in settingsURLs where workspace.open(url) {
            return true
        }

        return false
    }
}
