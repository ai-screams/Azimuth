import Foundation

nonisolated enum WindowCommandError: Error, Equatable {
    case resolution(WindowResolutionError)
    case workAreaUnavailable
    case notMovable
    case applyFailed
    /// Space 전환·창 애니메이션 중 일시적으로 적용 불가(AX cannotComplete). 사용자 피드백 없이 조용히 스킵.
    case transient
    case noUndoState

    /// UI(상태바 메뉴·알림)에 그대로 노출된다 — 나머지 UI와 같이 영어로 유지(현지화는 추후 일괄).
    var userFacingMessage: String {
        switch self {
        case let .resolution(error):
            error.userFacingMessage
        case .workAreaUnavailable:
            "Couldn't determine the screen work area"
        case .notMovable:
            "This window can't be moved or resized"
        case .applyFailed:
            "Couldn't apply the new frame to the window"
        case .transient:
            "Try again in a moment"
        case .noUndoState:
            "Nothing to undo"
        }
    }
}
