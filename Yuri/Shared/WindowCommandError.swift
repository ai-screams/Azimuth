import Foundation

nonisolated enum WindowCommandError: Error, Equatable {
    case resolution(WindowResolutionError)
    case workAreaUnavailable
    case notMovable
    case applyFailed
    case noUndoState

    var userFacingMessage: String {
        switch self {
        case let .resolution(error):
            error.userFacingMessage
        case .workAreaUnavailable:
            "작업영역을 찾을 수 없음"
        case .notMovable:
            "이 창은 이동/리사이즈할 수 없음"
        case .applyFailed:
            "창에 적용하지 못함"
        case .noUndoState:
            "되돌릴 상태가 없음"
        }
    }
}
