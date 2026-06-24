import Foundation

nonisolated enum WindowCommandError: Error, Equatable {
    case resolution(WindowResolutionError)
    case workAreaUnavailable
    case notMovable
    case applyFailed
    /// Space 전환·창 애니메이션 중 일시적으로 적용 불가(AX cannotComplete). 사용자 피드백 없이 조용히 스킵.
    case transient
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
        case .transient:
            "잠시 후 다시 시도하세요"
        case .noUndoState:
            "되돌릴 상태가 없음"
        }
    }
}
