import AppKit

/// 레거시판(macOS 10.13~12)에서 OS가 지원하지 않는 기능을 한곳에서 판정한다.
nonisolated enum LegacySupport {
    /// 로그인 자동 실행(`SMAppService`, 13+).
    static var launchAtLogin: Bool {
        if #available(macOS 13.0, *) { true } else { false }
    }

    /// 명령 실패 알림(`UNUserNotificationCenter` 10.14 + async 요청 10.15).
    static var failureNotifications: Bool {
        if #available(macOS 10.15, *) { true } else { false }
    }
}

/// `MainActor.assumeIsolated`(10.15+) 백포트. 10.15+에서는 그대로 위임한다.
///
/// SAFETY(10.15 미만): 그 OS에는 동시성 런타임의 격리 검사가 없다. 메인 큐임을 `dispatchPrecondition`으로
/// 단언한 뒤, 같은 클로저를 비격리 함수 타입으로 바꿔(`unsafeBitCast`, 전역 액터 격리는 호출 규약을 바꾸지
/// 않는다) 직접 실행한다. 호출해도 되는 곳은 셋뿐이다 — `main.swift` 최상위, Carbon 핫키 콜백
/// (`HotkeyService`, `GetApplicationEventTarget`), `DispatchQueue.main` 작업 항목(`AnimationSuppressor`).
/// 새 호출 지점을 늘리지 말 것. 각 경로는 레거시 RC 실기 게이트에서 확인한다.
nonisolated func unsafeAssumeMainActor(_ body: @MainActor () -> Void) {
    if #available(macOS 10.15, *) {
        MainActor.assumeIsolated(body)
    } else {
        dispatchPrecondition(condition: .onQueue(.main))
        withoutActuallyEscaping(body) { escapable in
            unsafeBitCast(escapable, to: (() -> Void).self)()
        }
    }
}

extension NSImage {
    /// SF Symbol(11+). 11 미만은 nil — 호출부는 장식 아이콘이므로 글자만 남는다.
    static func symbol(_ name: String, accessibilityDescription: String? = nil) -> NSImage? {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        }
        return nil
    }
}

extension NSImageView {
    func setTint(_ color: NSColor?) {
        if #available(macOS 10.14, *) { contentTintColor = color }
    }

    /// SF Symbol을 넣고, 11 미만이라 없으면 뷰를 숨긴다 — NSStackView가 숨은 뷰의 자리를 접어
    /// 아이콘 없는 제목·행이 들여쓰기된 채 남지 않게 한다.
    func setSymbol(_ name: String) {
        image = NSImage.symbol(name)
        isHidden = image == nil
    }
}

extension NSButton {
    func setTint(_ color: NSColor?) {
        if #available(macOS 10.14, *) { contentTintColor = color }
    }
}
