//
//  ShortcutRecordingPolicy.swift
//  Azimuth
//
//  Shortcuts 화면에서 "지금 어느 명령을 녹화 중인가"와 전역 단축키 일시 정지의 전이. 녹화 중에는 전역 단축키를
//  멈추고(누르는 조합이 뒤의 창을 움직이지 않게) 끝나면 다시 켠다. 멈춤과 재개가 어긋나면 단축키가 멈춘 채
//  남는다(#137). 그래서 전이를 값으로 두고 순서까지 테스트한다. 명령은 저장 식별자(`WindowCommand.identifier`)로 다룬다.
//

import Foundation

nonisolated struct ShortcutRecordingStep: Equatable {
    /// 다음에 녹화 중인 명령. nil이면 녹화 안 함.
    let recording: String?
    /// 전역 단축키 일시 정지를 바꿀지. true 멈춤, false 재개, nil 그대로.
    let suspend: Bool?
}

nonisolated enum ShortcutRecordingPolicy {
    /// 키캡을 눌렀을 때. 녹화 중인 그 줄을 다시 누르면 취소, 다른 줄이면 그 줄로 옮긴다(단축키는 계속 멈춤).
    static func toggle(_ identifier: String, current: String?) -> ShortcutRecordingStep {
        if current == identifier { return ShortcutRecordingStep(recording: nil, suspend: false) }
        return ShortcutRecordingStep(recording: identifier, suspend: current == nil ? true : nil)
    }

    /// 녹화 칸이 끝을 알렸을 때(기록·취소). 다른 줄로 옮긴 뒤 이전 칸이 뒤늦게 알리면 nil(무시).
    static func finish(_ identifier: String, current: String?) -> ShortcutRecordingStep? {
        guard current == identifier else { return nil }
        return ShortcutRecordingStep(recording: nil, suspend: false)
    }

    /// 녹화 중인 줄이 화면에서 사라졌는가(접기·검색). 그러면 취소해야 한다.
    static func isHidden(current: String?, visible: Set<String>) -> Bool {
        guard let current else { return false }
        return !visible.contains(current)
    }
}
