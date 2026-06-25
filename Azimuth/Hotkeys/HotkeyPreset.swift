//
//  HotkeyPreset.swift
//  Azimuth
//

import Carbon.HIToolbox

nonisolated struct HotkeyBinding {
    let command: WindowCommand
    let keyCode: UInt32
    let modifiers: UInt32
}

nonisolated enum HotkeyPreset: String, CaseIterable {
    case standard
    case vim

    var displayName: String {
        switch self {
        case .standard:
            "Standard"
        case .vim:
            "Vim"
        }
    }

    var bindings: [HotkeyBinding] {
        let base = UInt32(controlKey | optionKey)
        let moveMods = UInt32(controlKey | optionKey | cmdKey)
        let relMods = UInt32(controlKey | optionKey | shiftKey)
        let displayMods = UInt32(controlKey | optionKey | cmdKey | shiftKey)
        let isVim = self == .vim

        // Direction keys: Vim uses HJKL, Standard uses arrow keys
        // Arrow keys: left=0x7B, right=0x7C, down=0x7D, up=0x7E
        // Vim keys: H=0x04, J=0x26, K=0x28, L=0x25
        let left = UInt32(isVim ? 0x04 : 0x7B)
        let right = UInt32(isVim ? 0x25 : 0x7C)
        let up = UInt32(isVim ? 0x28 : 0x7E)
        let down = UInt32(isVim ? 0x26 : 0x7D)

        // Undo: Vim uses U=0x20, Standard uses Delete=0x33
        let undoKey = UInt32(isVim ? 0x20 : 0x33)

        return snapThrowBindings(left: left, right: right, up: up, down: down, base: base)
            + coreBindings(undoKey: undoKey, base: base)
            + moveBindings(left: left, right: right, up: up, down: down, moveMods: moveMods)
            + relativeHalfBindings(left: left, right: right, up: up, down: down, relMods: relMods)
            + displayMoveBindings(left: left, right: right, up: up, down: down, displayMods: displayMods)
            + thirdBindings(base: base)
            + twoThirdBindings(base: base)
    }

    private func displayMoveBindings(
        left: UInt32,
        right: UInt32,
        up: UInt32,
        down: UInt32,
        displayMods: UInt32
    ) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .moveToDisplay(.left), keyCode: left, modifiers: displayMods),
            HotkeyBinding(command: .moveToDisplay(.right), keyCode: right, modifiers: displayMods),
            HotkeyBinding(command: .moveToDisplay(.top), keyCode: up, modifiers: displayMods),
            HotkeyBinding(command: .moveToDisplay(.bottom), keyCode: down, modifiers: displayMods)
        ]
    }

    private func snapThrowBindings(
        left: UInt32,
        right: UInt32,
        up: UInt32,
        down: UInt32,
        base: UInt32
    ) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .snapThrow(.left), keyCode: left, modifiers: base),
            HotkeyBinding(command: .snapThrow(.right), keyCode: right, modifiers: base),
            HotkeyBinding(command: .snapThrow(.top), keyCode: up, modifiers: base),
            HotkeyBinding(command: .snapThrow(.bottom), keyCode: down, modifiers: base)
        ]
    }

    private func coreBindings(undoKey: UInt32, base: UInt32) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .maximize, keyCode: 0x24, modifiers: base),
            HotkeyBinding(command: .undo, keyCode: undoKey, modifiers: base),
            HotkeyBinding(command: .move(.center), keyCode: 0x08, modifiers: base)
        ]
    }

    private func moveBindings(
        left: UInt32,
        right: UInt32,
        up: UInt32,
        down: UInt32,
        moveMods: UInt32
    ) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .move(.left), keyCode: left, modifiers: moveMods),
            HotkeyBinding(command: .move(.right), keyCode: right, modifiers: moveMods),
            HotkeyBinding(command: .move(.up), keyCode: up, modifiers: moveMods),
            HotkeyBinding(command: .move(.down), keyCode: down, modifiers: moveMods)
        ]
    }

    private func relativeHalfBindings(
        left: UInt32,
        right: UInt32,
        up: UInt32,
        down: UInt32,
        relMods: UInt32
    ) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .relativeHalf(.left), keyCode: left, modifiers: relMods),
            HotkeyBinding(command: .relativeHalf(.right), keyCode: right, modifiers: relMods),
            HotkeyBinding(command: .relativeHalf(.top), keyCode: up, modifiers: relMods),
            HotkeyBinding(command: .relativeHalf(.bottom), keyCode: down, modifiers: relMods)
        ]
    }

    private func thirdBindings(base: UInt32) -> [HotkeyBinding] {
        [
            // Horizontal 1/3: ⌃⌥ 1/2/3
            makeAbsolute(.horizontal, .third, .first, 0x12, base),
            makeAbsolute(.horizontal, .third, .center, 0x13, base),
            makeAbsolute(.horizontal, .third, .last, 0x14, base),
            // Vertical 1/3: ⌃⌥ 4/5/6
            makeAbsolute(.vertical, .third, .first, 0x15, base),
            makeAbsolute(.vertical, .third, .center, 0x17, base),
            makeAbsolute(.vertical, .third, .last, 0x16, base)
        ]
    }

    private func twoThirdBindings(base: UInt32) -> [HotkeyBinding] {
        [
            // Horizontal 2/3: ⌃⌥ 7/8
            makeAbsolute(.horizontal, .twoThird, .first, 0x1A, base),
            makeAbsolute(.horizontal, .twoThird, .last, 0x1C, base),
            // Vertical 2/3: ⌃⌥ 9/0
            makeAbsolute(.vertical, .twoThird, .first, 0x19, base),
            makeAbsolute(.vertical, .twoThird, .last, 0x1D, base)
        ]
    }

    private func makeAbsolute(
        _ axis: Axis,
        _ fraction: Fraction,
        _ slot: Slot,
        _ keyCode: UInt32,
        _ modifiers: UInt32
    ) -> HotkeyBinding {
        HotkeyBinding(
            command: .absolute(AbsolutePlacement(axis: axis, fraction: fraction, slot: slot)),
            keyCode: keyCode,
            modifiers: modifiers
        )
    }
}
