import ApplicationServices
import Cocoa

struct ResolvedWindow: Equatable {
    let element: AXUIElement
    let subrole: String
    let pid: pid_t
    let frame: WindowFrame
}

enum FocusedWindowResolver {
    private static let supportedSubroles: Set<String> = [kAXStandardWindowSubrole as String]

    static func resolveFocusedWindow(for app: NSRunningApplication) -> Result<ResolvedWindow, WindowResolutionError> {
        guard AccessibilityPermissionService.currentStatus().isTrusted else {
            return .failure(.permissionDenied)
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let (windowOrNil, windowError) = AXAttribute.element(appElement, kAXFocusedWindowAttribute as String)
        guard windowError == .success, let window = windowOrNil else {
            return .failure(mapWindowLookupError(windowError))
        }

        // 풀스크린은 subrole로 구분 불가 → subrole 검사보다 먼저, 비공개 "AXFullScreen" 속성으로 판별.
        if AXAttribute.bool(window, "AXFullScreen") == true {
            return .failure(.fullscreenWindow)
        }

        // 방어적 최소화 검사 (포커스 경로에서는 보통 NoValue로 이미 걸림).
        if AXAttribute.bool(window, kAXMinimizedAttribute as String) == true {
            return .failure(.noFocusedWindow)
        }

        let subrole = AXAttribute.string(window, kAXSubroleAttribute as String)
        guard let subrole, supportedSubroles.contains(subrole) else {
            return .failure(.unsupportedWindowType(subrole: subrole))
        }

        guard let origin = AXAttribute.point(window, kAXPositionAttribute as String),
              let size = AXAttribute.size(window, kAXSizeAttribute as String)
        else {
            return .failure(.axError(code: AXError.noValue.rawValue))
        }

        return .success(ResolvedWindow(
            element: window,
            subrole: subrole,
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
}
