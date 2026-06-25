//
//  BindingResolver.swift
//  Azimuth
//
//  프리셋 기본 바인딩에 사용자 커스텀 단축키(override)를 덮어써 실효 바인딩을 만들고,
//  앱 내부 조합 충돌(같은 키 조합을 두 명령 이상이 사용)을 검출한다.
//

import Foundation

nonisolated enum BindingResolver {
    /// 프리셋 기본값에 override를 적용한 실효 바인딩. override는 명령 identifier로 매칭한다.
    /// 불변식: 프리셋 바인딩에 없는 identifier의 override는 무시된다(현재 두 프리셋은 29개 명령을
    /// 모두 포함하므로 무해). 프리셋이 명령 집합을 달리하게 되면 고아 override 처리 정책을 추가할 것.
    static func resolve(preset: HotkeyPreset, overrides: [String: HotkeyShortcut]) -> [HotkeyBinding] {
        preset.bindings.map { binding in
            guard let shortcut = overrides[binding.command.identifier] else { return binding }
            return HotkeyBinding(
                command: binding.command,
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers
            )
        }
    }

    /// 그룹 off 또는 개별 unbind된 명령을 제외한, 실제 등록 대상 바인딩만 남긴다.
    static func enabled(
        _ bindings: [HotkeyBinding],
        disabledCommands: Set<String>,
        disabledGroups: Set<String>
    ) -> [HotkeyBinding] {
        bindings.filter { binding in
            !disabledGroups.contains(binding.command.group.token)
                && !disabledCommands.contains(binding.command.identifier)
        }
    }

    /// 같은 (keyCode, modifiers) 조합을 2개 이상 명령이 쓰면, 그 명령들의 identifier를 모두 반환한다.
    static func conflictingIdentifiers(in bindings: [HotkeyBinding]) -> Set<String> {
        var byCombo: [Combo: [String]] = [:]
        for binding in bindings {
            let combo = Combo(keyCode: binding.keyCode, modifiers: binding.modifiers)
            byCombo[combo, default: []].append(binding.command.identifier)
        }
        var conflicts: Set<String> = []
        for identifiers in byCombo.values where identifiers.count > 1 {
            conflicts.formUnion(identifiers)
        }
        return conflicts
    }

    private struct Combo: Hashable {
        let keyCode: UInt32
        let modifiers: UInt32
    }
}
