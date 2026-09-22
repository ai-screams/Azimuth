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
            "Accessibility access is enabled. Shortcuts and menu commands can move and resize other app windows."
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

    /// 권한 요청 프롬프트를 띄우고 캐시를 갱신한다. 반환값은 쓰이지 않는다 —
    /// 프롬프트 직후의 신뢰 상태는 사용자가 System Settings에서 조작하기 전 값이라 의미가 없다.
    static func requestPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trustedCache = AXIsProcessTrustedWithOptions(options)
    }

    /// "권한 설정 열기" 버튼/메뉴의 동작 전체. 프롬프트를 띄우고 System Settings를 연다.
    /// 설정창을 열지 못했으면 false — 호출부가 사용자에게 알린다(피드백은 UI의 몫이라 여기서 소리내지 않는다).
    ///
    /// 두 곳(설정창 Permissions 카드, 상태바 메뉴)이 같은 다섯 줄을 복제하고 있어 합쳤다.
    @discardableResult
    static func promptAndOpenSettings() -> Bool {
        requestPrompt()
        return openSystemSettings()
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
