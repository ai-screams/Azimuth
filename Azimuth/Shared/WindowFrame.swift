import CoreGraphics

nonisolated struct WindowFrame: Equatable {
    var origin: CGPoint
    var size: CGSize

    var rect: CGRect {
        CGRect(origin: origin, size: size)
    }
}

nonisolated enum WindowResolutionError: Error, Equatable {
    case permissionDenied
    case noFrontmostApplication
    case noFocusedWindow
    case appUnresponsive(code: Int32)
    case unsupportedWindowType(subrole: String?)
    case fullscreenWindow
    case invalidFrame
    case axError(code: Int32)

    /// UI(상태바 메뉴·알림)에 그대로 노출된다 — 나머지 UI와 같이 영어로 유지(현지화는 추후 일괄).
    var userFacingMessage: String {
        switch self {
        case .permissionDenied:
            "Accessibility permission required"
        case .noFrontmostApplication:
            "No active application"
        case .noFocusedWindow:
            "No focused window to control"
        case .appUnresponsive:
            "The app is not responding"
        case let .unsupportedWindowType(subrole):
            "Unsupported window type (\(subrole ?? "unknown"))"
        case .fullscreenWindow:
            "Full screen windows aren't supported"
        case .invalidFrame:
            "The window reported an invalid size or position"
        case let .axError(code):
            "Couldn't access the window (error \(code))"
        }
    }
}
