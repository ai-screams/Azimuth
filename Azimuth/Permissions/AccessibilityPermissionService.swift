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
            if #available(macOS 13.0, *) {
                "Enable Accessibility access for Azimuth in System Settings > Privacy & Security > Accessibility."
            } else {
                "Enable Accessibility access for Azimuth in "
                    + "System Preferences > Security & Privacy > Privacy > Accessibility."
            }
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

    /// 권한 요청 알림을 띄우고 캐시를 갱신한다. 알림은 비동기라 반환값(신뢰 여부)은 사용자가 답하기 전
    /// 값이므로 쓰지 않는다.
    private static func requestPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trustedCache = AXIsProcessTrustedWithOptions(options)
    }

    /// "권한 설정 열기" 버튼/메뉴(설정창 Permissions 카드, 상태바 메뉴)의 동작 전체. 알림을 띄울지 설정을
    /// 바로 열지는 `AccessibilityRequestPolicy`가 정한다 — 둘을 동시에 하면 알림에 답하기 전에 설정이 먼저
    /// 뜬다. 알림 경로는 시도 기록을 **먼저** 남기고, 앱을 앞으로 가져온 뒤 다음 런루프에서 요청한다
    /// (활성화는 즉시 끝난다는 보장이 없어, 메뉴 막대에서 누른 경우 알림이 다른 창 뒤에 숨지 않게).
    ///
    /// 반환: 알림 요청을 보냈거나 설정을 열었으면 true, 설정을 열지 못했으면 false(호출부가 알린다 — 피드백은
    /// UI의 몫이라 여기서 소리내지 않는다). true가 알림이 실제로 떴다거나 권한이 생겼다는 뜻은 아니다.
    @discardableResult
    static func requestAccess(preferences: PreferencesStore) -> Bool {
        invalidateCache()
        let action = AccessibilityRequestPolicy.decide(
            isTrusted: isTrustedCached(), didAttemptPrompt: preferences.didAttemptAccessibilityPrompt
        )
        switch action {
        case .systemPrompt:
            preferences.didAttemptAccessibilityPrompt = true
            NSApp.bringToFront()
            DispatchQueue.main.async { requestPrompt() }
            return true
        case .openSettings:
            return openSystemSettings()
        }
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
