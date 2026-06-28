import ApplicationServices
import Cocoa

nonisolated struct ResolvedWindow: Equatable {
    let element: AXUIElement
    /// 대상 앱 엘리먼트(창 아님). WindowFrameWriter가 쓰기 직전 AXEnhancedUserInterface 등을
    /// 끄는 데 쓴다. resolve 시 이미 생성·2s 타임아웃을 건 것을 재사용한다(pid 재생성 금지).
    let appElement: AXUIElement
    let subrole: String
    let pid: pid_t
    let frame: WindowFrame
}

@MainActor
enum FocusedWindowResolver {
    private static let supportedSubroles: Set<String> = [
        kAXStandardWindowSubrole as String,
        kAXDialogSubrole as String
    ]

    /// 비공개 속성. 풀스크린은 subrole로 구분 불가해 이 속성으로 판별한다(macOS 10.11+ 사실상 표준).
    private static let fullScreenAttribute = "AXFullScreen"

    /// AX IPC는 동기라 응답 없는 앱이 메인 스레드를 막을 수 있다(기본 6초). 2초로 상한을 둔다.
    private static let messagingTimeout: Float = 2.0

    static func resolveFocusedWindow(for app: NSRunningApplication) -> Result<ResolvedWindow, WindowResolutionError> {
        guard AccessibilityPermissionService.currentStatus().isTrusted else {
            return .failure(.permissionDenied)
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
        let (windowOrNil, windowError) = AXAttribute.element(appElement, kAXFocusedWindowAttribute as String)
        guard windowError == .success, let window = windowOrNil else {
            return .failure(mapWindowLookupError(windowError))
        }
        // 타임아웃은 element 단위라 창 element에도 건다(이후 읽기 + WindowFrameWriter의 쓰기까지 적용).
        AXUIElementSetMessagingTimeout(window, messagingTimeout)

        // 풀스크린은 subrole로 구분 불가 → subrole 검사보다 먼저, 비공개 "AXFullScreen" 속성으로 판별.
        if AXAttribute.bool(window, fullScreenAttribute) == true {
            return .failure(.fullscreenWindow)
        }

        // 방어적 최소화 검사 (포커스 경로에서는 보통 NoValue로 이미 걸림).
        if AXAttribute.bool(window, kAXMinimizedAttribute as String) == true {
            return .failure(.noFocusedWindow)
        }

        // 표준 창/다이얼로그는 허용. 그 외(JetBrains 등 자바/AWT, 일부 Electron의 비표준·누락 subrole)는
        // 위치·크기를 실제로 설정할 수 있을 때만 허용한다(시트·팝오버 등은 settable=false라 계속 차단).
        let subrole = AXAttribute.string(window, kAXSubroleAttribute as String)
        let isSupportedSubrole = subrole.map(supportedSubroles.contains) ?? false
        guard isSupportedSubrole || isMovableAndResizable(window) else {
            return .failure(.unsupportedWindowType(subrole: subrole))
        }

        guard let origin = AXAttribute.point(window, kAXPositionAttribute as String),
              let size = AXAttribute.size(window, kAXSizeAttribute as String)
        else {
            return .failure(.axError(code: AXError.noValue.rawValue))
        }

        return .success(ResolvedWindow(
            element: window,
            appElement: appElement,
            subrole: subrole ?? (kAXUnknownSubrole as String),
            pid: app.processIdentifier,
            frame: WindowFrame(origin: origin, size: size)
        ))
    }

    static func resolveFrontmostFocusedWindow(
        tracker: FrontmostAppTracker
    ) -> Result<ResolvedWindow, WindowResolutionError> {
        guard let app = tracker.targetApplication else {
            return .failure(.noFrontmostApplication)
        }
        return resolveFocusedWindow(for: app)
    }

    private static func mapWindowLookupError(_ error: AXError) -> WindowResolutionError {
        switch error {
        case .noValue:
            .noFocusedWindow
        case .apiDisabled:
            .permissionDenied
        case .cannotComplete, .notImplemented, .attributeUnsupported:
            .appUnresponsive(code: error.rawValue)
        default:
            .axError(code: error.rawValue)
        }
    }

    /// 위치·크기 속성을 실제로 설정할 수 있는 창인지. subrole이 비표준/누락이어도
    /// 이동·리사이즈가 가능하면 지원 대상으로 본다(JetBrains 등 자바 창 대응).
    private static func isMovableAndResizable(_ window: AXUIElement) -> Bool {
        func settable(_ attribute: String) -> Bool {
            var flag = DarwinBoolean(false)
            let err = AXUIElementIsAttributeSettable(window, attribute as CFString, &flag)
            return err == .success && flag.boolValue
        }
        return settable(kAXPositionAttribute as String) && settable(kAXSizeAttribute as String)
    }
}
