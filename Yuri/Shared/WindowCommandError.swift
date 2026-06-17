import Foundation

enum WindowCommandError: Error, Equatable {
    case resolution(WindowResolutionError)
    case workAreaUnavailable
    case notMovable

    var userFacingMessage: String {
        switch self {
        case let .resolution(error):
            error.userFacingMessage
        case .workAreaUnavailable:
            "작업영역을 찾을 수 없음"
        case .notMovable:
            "이 창은 이동/리사이즈할 수 없음"
        }
    }
}
