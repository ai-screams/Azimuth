//
//  AccessibilityPermissionService.swift
//  Azimuth
//
//  Created by Codex on 3/31/26.
//

import ApplicationServices
import Cocoa

nonisolated enum AccessibilityPermissionStatus {
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
            "Azimuth can control other app windows."
        case .required:
            "Azimuth cannot control other app windows yet."
        }
    }

    var settingsDetailText: String {
        switch self {
        case .granted:
            "Accessibility access is enabled. You can continue with command wiring and window control."
        case .required:
            "Enable Accessibility access for Azimuth in System Settings > Privacy & Security > Accessibility."
        }
    }
}

@MainActor
enum AccessibilityPermissionService {
    private static let settingsURLs = [
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security"
    ].compactMap(URL.init(string:))

    /// AXIsProcessTrusted()는 tccd 동기 호출이라 핫키마다 부르지 않도록 캐시한다.
    /// 권한 변경은 앱 활성화(didBecomeActive) 시 invalidateCache()로 반영한다.
    private static var trustedCache: Bool?

    static func currentStatus() -> AccessibilityPermissionStatus {
        isTrustedCached() ? .granted : .required
    }

    /// 캐시된 신뢰 상태(없으면 한 번 조회해 채움).
    private static func isTrustedCached() -> Bool {
        if let trustedCache { return trustedCache }
        let trusted = AXIsProcessTrusted()
        trustedCache = trusted
        return trusted
    }

    /// 권한 상태가 바뀌었을 수 있을 때(앱 활성화 등) 캐시를 비운다.
    static func invalidateCache() {
        trustedCache = nil
    }

    @discardableResult
    static func requestPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        trustedCache = trusted
        return trusted
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
