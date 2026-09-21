// 단축키 바인딩 계층 회귀 테스트.
//
// 이 네 파일(BindingResolver·HotkeyPreset·HotkeyShortcut·CarbonModifier)은 순수 로직인데
// 오랫동안 하네스 밖에 있었다. "AppKit을 import하니 하네스가 깨진다"는 문서의 주장이 근거였는데,
// 실측 결과 그 제약은 존재하지 않는다 — 넣을 수 없는 것은 AXUIElement 를 운반해 값으로 만들 수
// 없는 타입이지, AppKit import 자체가 아니다.
//
// 여기서 지키는 것은 전부 사용자에게 바로 보이는 동작이다: 어떤 단축키가 실제로 등록되는가,
// 충돌 배지가 언제 뜨는가, 설정창에 조합이 어떻게 표시되는가, 저장된 단축키가 살아남는가.

import AppKit
import Carbon.HIToolbox
import Foundation

extension CommandEngineTests {
    /// 프리셋은 34개 명령을 정확히 한 번씩 덮어야 한다. `Hotkeys/AGENTS.md`는 이것이 빌드 시점에
    /// 확인된다고 적었지만 실제로는 아무도 검사하지 않았다 — 누락되면 그 명령은 **기본 단축키가 없고**,
    /// 중복되면 뒤엣것이 조용히 이긴다.
    static func testPresetCoverage() {
        let all = Set(WindowCommand.menuCommands.map(\.identifier))
        for preset in HotkeyPreset.allCases {
            let ids = preset.bindings.map(\.command.identifier)
            expectName("\(preset.rawValue): 바인딩 수 = 명령 수", "\(ids.count)", "\(all.count)")
            expectName("\(preset.rawValue): 중복 없음", "\(Set(ids).count)", "\(ids.count)")
            expectName("\(preset.rawValue): menuCommands 전부 덮음", "\(Set(ids) == all)", "true")
            // 기본 상태에서 충돌 배지가 뜨면 안 된다.
            let conflicts = BindingResolver.conflictingIdentifiers(in: preset.bindings)
            expectName("\(preset.rawValue): 조합 충돌 0", "\(conflicts.count)", "0")
        }
        expectName("standard displayName", HotkeyPreset.standard.displayName, "Standard")
        expectName("vim displayName", HotkeyPreset.vim.displayName, "Vim")
    }

    /// override 병합. 프리셋에 있는 명령만 덮어쓰고, 없는 identifier 는 무시한다(문서화된 불변식).
    static func testBindingOverrides() {
        let preset = HotkeyPreset.standard
        let target = preset.bindings[0].command
        let custom = HotkeyShortcut(keyCode: 0x2B, modifiers: UInt32(cmdKey))
        let resolved = BindingResolver.resolve(preset: preset, overrides: [target.identifier: custom])
        expectName("override 후에도 바인딩 수 동일", "\(resolved.count)", "\(preset.bindings.count)")
        let hit = resolved.first { $0.command.identifier == target.identifier }
        expectName("override 가 keyCode 를 덮음", "\(hit?.keyCode ?? 0)", "\(custom.keyCode)")
        expectName("override 가 modifiers 를 덮음", "\(hit?.modifiers ?? 0)", "\(custom.modifiers)")
        // 프리셋에 없는 identifier 는 무시된다 — 바인딩이 늘지 않는다.
        let ghost = BindingResolver.resolve(preset: preset, overrides: ["no.such.command": custom])
        expectName("고아 override 는 무시", "\(ghost.count)", "\(preset.bindings.count)")
        // HotkeyBinding 은 Equatable 이 아니다(이 PR 은 프로덕션 코드를 건드리지 않는다) — 파생 값으로 비교.
        func fingerprint(_ list: [HotkeyBinding]) -> String {
            list.map { "\($0.command.identifier):\($0.keyCode):\($0.modifiers)" }.joined(separator: "|")
        }
        expectName("고아 override 는 기존을 안 건드림", fingerprint(ghost), fingerprint(preset.bindings))
    }

    /// 그룹/개별 비활성 필터. 여기가 틀리면 **끈 단축키가 등록된다.**
    static func testEnabledFiltering() {
        let bindings = HotkeyPreset.standard.bindings
        let halvesCount = bindings.filter { $0.command.group == .halves }.count
        expectName("halves 그룹이 비어있지 않음", "\(halvesCount > 0)", "true")

        let groupOff = BindingResolver.enabled(bindings, disabledCommands: [], disabledGroups: ["halves"])
        expectName("그룹 비활성이 그 그룹을 전부 뺀다", "\(groupOff.count)", "\(bindings.count - halvesCount)")
        expectName("남은 것에 halves 없음", "\(groupOff.contains { $0.command.group == .halves })", "false")

        let one = bindings[0].command.identifier
        let cmdOff = BindingResolver.enabled(bindings, disabledCommands: [one], disabledGroups: [])
        expectName("개별 비활성은 하나만 뺀다", "\(cmdOff.count)", "\(bindings.count - 1)")
        expectName("뺀 것이 그 명령", "\(cmdOff.contains { $0.command.identifier == one })", "false")

        // 그룹과 개별이 겹쳐도 한 번만 빠진다(이중 차감 금지).
        let halvesFirst = bindings.first { $0.command.group == .halves }!.command.identifier
        let both = BindingResolver.enabled(
            bindings, disabledCommands: [halvesFirst], disabledGroups: ["halves"]
        )
        expectName("겹쳐도 이중 차감 없음", "\(both.count)", "\(bindings.count - halvesCount)")

        expectName("아무것도 안 끄면 그대로", "\(BindingResolver.enabled(bindings, disabledCommands: [], disabledGroups: []).count)", "\(bindings.count)")
    }

    /// 충돌 검출 — 설정창 "Duplicate" 배지의 유일한 근거다.
    static func testConflictDetection() {
        let commands = WindowCommand.menuCommands
        let same = HotkeyShortcut(keyCode: 0x24, modifiers: UInt32(controlKey | optionKey))
        func binding(_ index: Int, _ shortcut: HotkeyShortcut) -> HotkeyBinding {
            HotkeyBinding(command: commands[index], keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
        }
        let two = [binding(0, same), binding(1, same)]
        let hit = BindingResolver.conflictingIdentifiers(in: two)
        expectName("충돌하면 **양쪽 모두** 반환", "\(hit.count)", "2")
        expectName("충돌 집합이 정확", "\(hit == Set([commands[0].identifier, commands[1].identifier]))", "true")

        // 3개 이상 충돌도 전부 반환한다.
        let three = [binding(0, same), binding(1, same), binding(2, same)]
        expectName("3중 충돌도 전부", "\(BindingResolver.conflictingIdentifiers(in: three).count)", "3")

        // 수정자만 달라도 충돌이 아니다.
        let other = HotkeyShortcut(keyCode: 0x24, modifiers: UInt32(cmdKey))
        expectName("수정자가 다르면 충돌 아님", "\(BindingResolver.conflictingIdentifiers(in: [binding(0, same), binding(1, other)]).count)", "0")
        expectName("빈 목록은 충돌 없음", "\(BindingResolver.conflictingIdentifiers(in: []).count)", "0")
    }

    /// 표시 문자열. 설정창 각 행에 그대로 보인다.
    static func testShortcutDisplay() {
        expectName("키 라벨(Return)", HotkeyShortcut.keyLabel(for: 0x24), "↩")
        expectName("키 라벨(왼쪽 화살표)", HotkeyShortcut.keyLabel(for: 0x7B), "←")
        // 알 수 없는 키코드는 빈 문자열이 아니라 진단 가능한 폴백이어야 한다.
        expectName("알 수 없는 키는 폴백", HotkeyShortcut.keyLabel(for: 9999), "key(9999)")
        let combo = HotkeyShortcut(keyCode: 0x7B, modifiers: UInt32(controlKey | optionKey))
        expectName("조합 문자열", combo.displayString, "⌃⌥←")
    }

    /// `customShortcuts` 는 JSON 으로 UserDefaults 에 영속된다(PreferencesStore).
    /// 프로퍼티명을 바꾸면 **사용자가 설정한 단축키가 전부 사라진다** — 왕복을 고정해 둔다.
    static func testShortcutCodableRoundTrip() {
        let original = HotkeyShortcut(keyCode: 0x7C, modifiers: UInt32(controlKey | shiftKey))
        guard let data = try? JSONEncoder().encode(["move.right": original]),
              let back = try? JSONDecoder().decode([String: HotkeyShortcut].self, from: data)
        else {
            expectName("Codable 왕복", "실패", "성공")
            return
        }
        expectName("왕복 후 동일", "\(back["move.right"] == original)", "true")
        // JSON 키 이름이 곧 저장 포맷이다. 바뀌면 기존 저장값이 디코딩되지 않는다.
        let json = String(data: data, encoding: .utf8) ?? ""
        expectName("JSON 에 keyCode 키", "\(json.contains("keyCode"))", "true")
        expectName("JSON 에 modifiers 키", "\(json.contains("modifiers"))", "true")
    }

    /// Carbon 마스크 ↔ 글리프 ↔ NSEvent 플래그. 세 표현의 단일 출처다.
    static func testCarbonModifier() {
        expectName("빈 마스크", CarbonModifier.glyphs(for: 0), "")
        expectName("표시 순서는 ⌃⌥⇧⌘", CarbonModifier.glyphs(for: UInt32(cmdKey | controlKey | shiftKey | optionKey)), "⌃⌥⇧⌘")
        expectName("단일 수정자", CarbonModifier.glyphs(for: UInt32(optionKey)), "⌥")

        // 녹화 경로(ShortcutRecorderButton)가 쓰는 방향. glyphs 만 테스트하면 여기가 0% 로 남는다.
        expectName("플래그 → 마스크(빈 값)", "\(CarbonModifier.mask(from: []))", "0")
        expectName("플래그 → 마스크(control)", "\(CarbonModifier.mask(from: .control))", "\(UInt32(controlKey))")
        let combo: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        expectName("플래그 → 마스크(전체)", "\(CarbonModifier.mask(from: combo))", "\(UInt32(controlKey | optionKey | shiftKey | cmdKey))")
        // device-independent 마스킹: capsLock 같은 비수정자 비트는 무시되어야 한다.
        expectName("capsLock 은 무시", "\(CarbonModifier.mask(from: [.control, .capsLock]))", "\(UInt32(controlKey))")
        // 두 방향이 서로의 역이어야 한다.
        expectName("왕복", CarbonModifier.glyphs(for: CarbonModifier.mask(from: [.command, .shift])), "⇧⌘")
    }
}
