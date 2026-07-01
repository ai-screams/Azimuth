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
            + coreBindings(undoKey: undoKey, base: base, relMods: relMods)
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

    private func coreBindings(undoKey: UInt32, base: UInt32, relMods: UInt32) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .maximize, keyCode: 0x24, modifiers: base),
            // 여백 최대화: ⌃⌥⇧↩ — Maximize(⌃⌥↩)에 ⇧만 더한 "여백 버전" 니모닉. Return(0x24)은
            // base 레이어에만 묶여 있어 relMods(⌃⌥⇧) 레이어에선 두 프리셋 모두 비어 충돌 없음.
            HotkeyBinding(command: .maximizeGaps, keyCode: 0x24, modifiers: relMods),
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

    /// 상대 2/3 축소: ⌃⌥⇧ + M , . / — 키보드 바닥줄 오른쪽 연속 4키를 왼→오 순서로
    /// 좌/하/상/우에 매핑한다(Vim HJKL과 같은 배치: M=H=좌, ,=J=하, .=K=상, /=L=우).
    /// 화살표 바로 옆이라 손 이동이 적고, relativeHalf(⌃⌥⇧+방향키)와 충돌하지 않으며
    /// 어느 프리셋도 M/,/./ 를 쓰지 않으므로 Standard·Vim 동일하다.
    private func relativeTwoThirdBindings(relMods: UInt32) -> [HotkeyBinding] {
        [
            HotkeyBinding(command: .relativeTwoThird(.left), keyCode: 0x2E, modifiers: relMods), // M
            HotkeyBinding(command: .relativeTwoThird(.bottom), keyCode: 0x2B, modifiers: relMods), // ,
            HotkeyBinding(command: .relativeTwoThird(.top), keyCode: 0x2F, modifiers: relMods), // .
            HotkeyBinding(command: .relativeTwoThird(.right), keyCode: 0x2C, modifiers: relMods) // /
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
