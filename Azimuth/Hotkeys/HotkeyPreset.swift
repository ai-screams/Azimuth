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

        /// 방향 키코드[left,right,up,down]를 캡처해 호출부를 짧게 유지하는 로컬 래퍼.
        func directional(_ commands: [WindowCommand], _ modifiers: UInt32) -> [HotkeyBinding] {
            directionalBindings(commands, keyCodes: [left, right, up, down], modifiers: modifiers)
        }

        return directional([.snapThrow(.left), .snapThrow(.right), .snapThrow(.top), .snapThrow(.bottom)], base)
            + coreBindings(undoKey: undoKey, base: base)
            + directional([.move(.left), .move(.right), .move(.up), .move(.down)], moveMods)
            + directional(
                [.relativeHalf(.left), .relativeHalf(.right), .relativeHalf(.top), .relativeHalf(.bottom)],
                relMods
            )
            + directional(
                [.moveToDisplay(.left), .moveToDisplay(.right), .moveToDisplay(.top), .moveToDisplay(.bottom)],
                displayMods
            )
            + thirdBindings(base: base)
            + twoThirdBindings(base: base)
            + relativeTwoThirdBindings(relMods: relMods)
    }

    /// `commands`와 `keyCodes`를 위치(left/right/up/down 순)로 짝지어 동일 수식키 바인딩으로 만든다.
    /// snapThrow/move/relativeHalf/moveToDisplay가 공유하던 4방향 골격을 일반화한 것.
    private func directionalBindings(
        _ commands: [WindowCommand],
        keyCodes: [UInt32],
        modifiers: UInt32
    ) -> [HotkeyBinding] {
        zip(commands, keyCodes).map { command, keyCode in
            HotkeyBinding(command: command, keyCode: keyCode, modifiers: modifiers)
        }
    }

    private func coreBindings(undoKey: UInt32, base: UInt32) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .maximize, keyCode: 0x24, modifiers: base),
            HotkeyBinding(command: .undo, keyCode: undoKey, modifiers: base),
            HotkeyBinding(command: .move(.center), keyCode: 0x08, modifiers: base)
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

    /// 상대 2/3 축소: ⌃⌥⇧ + 7/8/9/0 (left/right/top/bottom). 절대 2/3가 ⌃⌥+7/8/9/0이라
    /// ⇧를 더한 같은 숫자열로 니모닉을 맞추고, relativeHalf(⌃⌥⇧+방향키)와 충돌하지 않는다.
    /// 숫자 키라 Standard·Vim 두 프리셋에서 동일하다.
    private func relativeTwoThirdBindings(relMods: UInt32) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .relativeTwoThird(.left), keyCode: 0x1A, modifiers: relMods),
            HotkeyBinding(command: .relativeTwoThird(.right), keyCode: 0x1C, modifiers: relMods),
            HotkeyBinding(command: .relativeTwoThird(.top), keyCode: 0x19, modifiers: relMods),
            HotkeyBinding(command: .relativeTwoThird(.bottom), keyCode: 0x1D, modifiers: relMods)
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
