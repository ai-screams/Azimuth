//
//  HotkeyShortcut.swift
//  Azimuth
//
//  커스텀 단축키 한 개(Carbon 키코드 + Carbon 수정자 마스크)의 값/표시.
//  NSEvent → 이 값으로의 변환은 UI 계층(ShortcutRecorderButton)에 둔다(AppKit 비의존 유지).
//

import Foundation

nonisolated struct HotkeyShortcut: Codable, Equatable {
    // 주의: Codable 자동 합성이 프로퍼티 이름을 JSON 키로 쓴다(UserDefaults에 영속).
    // 프로퍼티 이름을 바꾸면 저장된 사용자 단축키가 디코딩 실패로 사라지므로 CodingKeys 마이그레이션 필요.
    let keyCode: UInt32
    /// Carbon 수정자 마스크(controlKey|optionKey|shiftKey|cmdKey).
    let modifiers: UInt32

    /// 메뉴/표시용 사람이 읽는 조합 문자열 (예: "⌃⌥←", "⌃⌥⇧K").
    var displayString: String {
        CarbonModifier.glyphs(for: modifiers) + Self.keyLabel(for: keyCode)
    }

    /// Carbon 가상 키코드(kVK_*) → 표시 라벨. 알 수 없으면 "key(코드)".
    static func keyLabel(for keyCode: UInt32) -> String {
        keyLabels[keyCode] ?? "key(\(keyCode))"
    }

    /// U.S. 레이아웃 기준의 정적 맵. (UCKeyTranslate 기반 레이아웃 인식은 v2 과제.)
    private static let keyLabels: [UInt32: String] = {
        var map: [UInt32: String] = [
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x24: "↩", 0x4C: "⌅", 0x33: "⌫", 0x75: "⌦",
            0x35: "⎋", 0x31: "Space", 0x30: "⇥", 0x73: "Home",
            0x77: "End", 0x74: "Page Up", 0x79: "Page Down"
        ]
        letterKeyCodes.forEach { map[$0.key] = $0.value }
        digitKeyCodes.forEach { map[$0.key] = $0.value }
        punctuationKeyCodes.forEach { map[$0.key] = $0.value }
        functionKeyCodes.forEach { map[$0.key] = $0.value }
        return map
    }()

    private static let letterKeyCodes: [UInt32: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F",
        0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
        0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R",
        0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
        0x10: "Y", 0x06: "Z"
    ]

    private static let digitKeyCodes: [UInt32: String] = [
        0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4",
        0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9"
    ]

    private static let punctuationKeyCodes: [UInt32: String] = [
        0x18: "=", 0x1B: "-", 0x1E: "]", 0x21: "[", 0x27: "'", 0x29: ";",
        0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2F: ".", 0x32: "`"
    ]

    private static let functionKeyCodes: [UInt32: String] = [
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12"
    ]
}
