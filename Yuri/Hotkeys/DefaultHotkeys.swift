//
//  DefaultHotkeys.swift
//  Yuri
//

import Carbon.HIToolbox

nonisolated enum DefaultHotkeys {
    struct Binding {
        let command: WindowCommand
        let keyCode: UInt32
        let modifiers: UInt32
    }

    /// ⌃⌥ + 키 (Rectangle류). 핵심 6개.
    static let standard: [Binding] = {
        let mods = UInt32(controlKey | optionKey)
        return [
            Binding(command: .maximize, keyCode: 0x24, modifiers: mods),
            Binding(
                command: .absolute(AbsolutePlacement(axis: .horizontal, fraction: .half, slot: .first)),
                keyCode: 0x7B,
                modifiers: mods
            ),
            Binding(
                command: .absolute(AbsolutePlacement(axis: .horizontal, fraction: .half, slot: .last)),
                keyCode: 0x7C,
                modifiers: mods
            ),
            Binding(
                command: .absolute(AbsolutePlacement(axis: .vertical, fraction: .half, slot: .first)),
                keyCode: 0x7E,
                modifiers: mods
            ),
            Binding(
                command: .absolute(AbsolutePlacement(axis: .vertical, fraction: .half, slot: .last)),
                keyCode: 0x7D,
                modifiers: mods
            ),
            Binding(command: .undo, keyCode: 0x33, modifiers: mods)
        ]
    }()
}
