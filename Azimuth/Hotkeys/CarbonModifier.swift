//
//  CarbonModifier.swift
//  Azimuth
//
//  Carbon 수정자 마스크 ↔ NSEvent 플래그 ↔ 표시 글리프의 단일 출처.
//  이전엔 ShortcutRecorderButton(플래그→마스크)와 HotkeyShortcut(마스크→글리프)이
//  같은 4개 수정자(⌃⌥⇧⌘)를 각자 나열했다.
//

import AppKit
import Carbon.HIToolbox

nonisolated enum CarbonModifier {
    private struct Modifier {
        let carbon: Int
        let flag: NSEvent.ModifierFlags
        let glyph: String
    }

    /// 표시·검사 순서(⌃⌥⇧⌘)의 수정자 표.
    private static let table: [Modifier] = [
        Modifier(carbon: controlKey, flag: .control, glyph: "⌃"),
        Modifier(carbon: optionKey, flag: .option, glyph: "⌥"),
        Modifier(carbon: shiftKey, flag: .shift, glyph: "⇧"),
        Modifier(carbon: cmdKey, flag: .command, glyph: "⌘")
    ]

    /// NSEvent 수정자 플래그 → Carbon 수정자 마스크.
    static func mask(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let device = flags.intersection(.deviceIndependentFlagsMask)
        return table.reduce(into: 0) { mask, entry in
            if device.contains(entry.flag) { mask |= UInt32(entry.carbon) }
        }
    }

    /// Carbon 수정자 마스크 → 글리프 문자열(⌃⌥⇧⌘ 순).
    static func glyphs(for mask: UInt32) -> String {
        table.reduce(into: "") { result, entry in
            if mask & UInt32(entry.carbon) != 0 { result += entry.glyph }
        }
    }
}
