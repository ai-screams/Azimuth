//
//  PermissionWatchPolicy.swift
//  Azimuth
//
//  설정 창이 열려 있는 동안 Accessibility 권한이 생기는 순간을 잡는다(#176). macOS는 권한 변경을 알리는
//  문서화된 알림을 주지 않아, 공개 API(`AXIsProcessTrusted`)를 주기적으로 다시 읽는다. 읽는 일은
//  `SettingsWindowController`가 하고, 여기서는 한 번 읽은 결과로 다음 할 일만 정한다.
//

import Foundation

nonisolated enum PermissionWatchPolicy {
    /// 다시 읽는 간격. 권한을 준 뒤 설정 창으로 돌아오기 전에 바뀌어 있을 만큼 짧고, tccd를 바쁘게 하지 않을 만큼 길다.
    static let interval: TimeInterval = 1

    enum Step: Equatable {
        /// 아직 권한이 없고 창이 열려 있다: 계속 읽는다.
        case keepWatching
        /// 권한이 생겼다: 화면을 갱신하고 멈춘다.
        case granted
        /// 창이 닫혔다: 볼 사람이 없으니 멈춘다.
        case stop
    }

    /// 권한을 먼저 본다. 창이 닫히는 순간에 권한이 생겼어도 메뉴 막대 아이콘은 갱신해야 한다.
    static func step(windowVisible: Bool, isTrusted: Bool) -> Step {
        if isTrusted { return .granted }
        return windowVisible ? .keepWatching : .stop
    }
}
