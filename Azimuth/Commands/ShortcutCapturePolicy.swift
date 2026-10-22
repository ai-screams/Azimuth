//
//  ShortcutCapturePolicy.swift
//  Azimuth
//
//  단축키 녹화 중 키 하나를 받았을 때의 판단. 키 입력은 `Settings/ShortcutKeyCatcher`(AppKit 뷰)가 받고
//  여기서는 값만 본다: Esc는 취소, Tab은 취소 후 포커스 이동, 키 반복은 무시, 수정키 없는 키는 거부
//  (전역 단축키에는 수정키가 필요하다), 나머지는 그 조합을 기록한다. 순서가 판단의 일부다(Esc가 먼저).
//

import Foundation

nonisolated enum ShortcutCaptureOutcome: Equatable {
    /// 녹화를 끝내고 아무것도 바꾸지 않는다.
    case cancel
    /// 녹화를 끝내고 다음 컨트롤로 포커스를 옮긴다(Tab이 녹화 칸에 갇히지 않게).
    case cancelAndMoveFocus
    /// 꾹 누른 키의 반복. 녹화를 이어 간다.
    case ignore
    /// 수정키가 없다. 경고음을 내고 녹화를 이어 간다.
    case reject
    case capture(HotkeyShortcut)
}

nonisolated enum ShortcutCapturePolicy {
    /// Carbon `kVK_Escape`, `kVK_Tab`. 순수 계층이라 Carbon을 import하지 않고 값으로 둔다.
    static let escapeKeyCode: UInt16 = 0x35
    static let tabKeyCode: UInt16 = 0x30

    static func decide(keyCode: UInt16, carbonModifiers: UInt32, isRepeat: Bool) -> ShortcutCaptureOutcome {
        if keyCode == escapeKeyCode { return .cancel }
        if keyCode == tabKeyCode { return .cancelAndMoveFocus }
        if isRepeat { return .ignore }
        guard carbonModifiers != 0 else { return .reject }
        return .capture(HotkeyShortcut(keyCode: UInt32(keyCode), modifiers: carbonModifiers))
    }
}
