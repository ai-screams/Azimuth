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
    case axError(code: Int32)

    var userFacingMessage: String {
        switch self {
        case .permissionDenied:
            "Accessibility 권한 필요"
        case .noFrontmostApplication:
            "활성 앱 없음"
        case .noFocusedWindow:
            "조작할 활성 창을 찾을 수 없음"
        case .appUnresponsive:
            "앱이 응답하지 않음"
        case let .unsupportedWindowType(subrole):
            "지원하지 않는 창 (\(subrole ?? "unknown"))"
        case .fullscreenWindow:
            "풀스크린 창은 지원하지 않음"
        case let .axError(code):
            "창 접근 실패 (\(code))"
        }
    }
}
