//
//  ShortcutsSettingsModel.swift
//  Azimuth
//
//  Shortcuts 화면의 모델: 프리셋, 검색어, 펼친 그룹, 녹화 중인 명령, 명령별 표시. 값의 주인은 `PreferencesStore`이고
//  표시 판정은 순수 정책이 한다(`ShortcutListPolicy` 그룹 표시, `ShortcutRowPolicy` 행 표시). 바꿀 때마다
//  `onHotkeysChanged`로 전역 단축키를 다시 등록하고 등록 결과(실패)까지 다시 읽는다.
//
//  녹화 중에는 전역 단축키를 멈춘다(누르는 조합이 뒤의 창을 움직이지 않게). 녹화가 끝나는 길은 전부
//  `finishRecording`이나 `cancelRecording`을 지나며, 녹화 중인 줄이 화면에서 사라지면(접기·검색·화면 전환·창 닫기)
//  녹화를 취소해 단축키가 멈춘 채 남지 않게 한다.
//

import Foundation
import Observation

@Observable
final class ShortcutsSettingsModel {
    struct Row: Identifiable {
        let command: WindowCommand
        let shortcut: HotkeyShortcut?
        let display: ShortcutRowDisplay

        var id: String {
            command.identifier
        }
    }

    /// 팔레트를 여는 단축키 줄(#183). 명령이 아니어서 그룹 밖, 화면 맨 위에 따로 있다.
    struct PaletteRow {
        let shortcut: HotkeyShortcut
        let display: ShortcutRowDisplay
    }

    struct GroupSection: Identifiable {
        let group: CommandGroup
        let isEnabled: Bool
        /// 하위 줄을 보이는지. 검색 중에는 걸린 그룹을 저절로 펼친다(`ShortcutListPolicy`).
        let isExpanded: Bool
        /// 검색어에 걸린 줄. 펼치지 않았으면 비어 있다.
        let rows: [Row]

        var id: String {
            group.rawValue
        }
    }

    @ObservationIgnored private let store: PreferencesStore
    @ObservationIgnored private let onHotkeysChanged: () -> Void
    @ObservationIgnored private let registrationFailures: () -> Set<String>
    @ObservationIgnored private let setHotkeysSuspended: (Bool) -> Void

    private(set) var preset: HotkeyPreset
    private(set) var query = ""
    /// 사용자가 펼친 그룹. 저장하지 않는다(화면을 열 때마다 전부 접힘).
    private(set) var expandedGroups: Set<CommandGroup> = []
    /// 녹화 중인 명령의 식별자. 바꾸는 길은 `apply(_:)` 하나다(일시 정지와 짝을 맞춘다).
    private(set) var recording: String?
    private var rows: [String: Row] = [:]
    private(set) var paletteRow = PaletteRow(
        shortcut: CommandPaletteShortcut.standard,
        display: ShortcutRowPolicy.decide(ShortcutRowInput(
            shortcutDisplay: nil, hasOverride: false, groupEnabled: true, commandOn: true, effective: true,
            isConflicting: false, registrationFailed: false
        ))
    )
    private var enabledGroups: Set<CommandGroup> = []

    init(dependencies: SettingsDependencies) {
        store = dependencies.preferencesStore
        onHotkeysChanged = dependencies.onHotkeysChanged
        registrationFailures = dependencies.registrationFailures
        setHotkeysSuspended = dependencies.setHotkeysSuspended
        preset = dependencies.preferencesStore.activePreset
        refresh()
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 보이는 그룹만, 메뉴 순서대로.
    var sections: [GroupSection] {
        let matched = WindowCommand.menuCommands.filter { ShortcutListPolicy.matches(query: query, command: $0) }
        let counts = Dictionary(grouping: matched, by: \.group).mapValues(\.count)
        let display = ShortcutListPolicy.display(
            matchedCounts: counts, isSearching: isSearching, expanded: expandedGroups
        )
        return CommandGroup.allCases.compactMap { group in
            guard let state = display[group], state.isHeaderVisible else { return nil }
            let inGroup = state.isExpanded ? matched.filter { $0.group == group } : []
            let groupRows = inGroup.compactMap { rows[$0.identifier] }
            return GroupSection(
                group: group, isEnabled: enabledGroups.contains(group), isExpanded: state.isExpanded, rows: groupRows
            )
        }
    }

    // MARK: - Reading

    /// 화면을 보일 때. 녹화를 끝내고, 펼침과 검색어를 지우고, 다시 읽는다.
    func appear() {
        cancelRecording()
        expandedGroups = []
        query = ""
        refresh()
    }

    /// 실효 바인딩·활성 상태·충돌·등록 실패를 다시 계산한다.
    func refresh() {
        preset = store.activePreset
        let overrides = store.customShortcuts
        let bindings = BindingResolver.resolve(preset: preset, overrides: overrides)
        let byIdentifier = Dictionary(
            bindings.map { ($0.command.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // 충돌·등록 실패는 실제로 등록되는 켜진 바인딩에만 뜻이 있다.
        let enabledBindings = BindingResolver.enabled(
            bindings,
            disabledCommands: store.disabledCommandIdentifiers,
            disabledGroups: store.disabledGroupTokens
        )
        let failures = registrationFailures()
        // 팔레트 단축키와 같은 조합을 쓰는 켜진 명령은 둘 다 Duplicate다.
        let paletteOn = store.commandPaletteEnabled
        let paletteShortcut = store.commandPaletteShortcut
        let paletteConflicts = paletteOn ? CommandPaletteShortcut.conflicts(paletteShortcut, in: enabledBindings) : []
        let conflicts = BindingResolver.conflictingIdentifiers(in: enabledBindings).union(paletteConflicts)
        paletteRow = PaletteRow(shortcut: paletteShortcut, display: ShortcutRowPolicy.decide(ShortcutRowInput(
            shortcutDisplay: paletteShortcut.displayString,
            hasOverride: store.hasCustomCommandPaletteShortcut,
            groupEnabled: true,
            commandOn: paletteOn,
            effective: paletteOn,
            isConflicting: !paletteConflicts.isEmpty,
            registrationFailed: failures.contains(CommandPaletteShortcut.identifier)
        )))

        enabledGroups = Set(CommandGroup.allCases.filter { store.isGroupEnabled($0.token) })
        var next: [String: Row] = [:]
        for command in WindowCommand.menuCommands {
            let identifier = command.identifier
            let groupEnabled = enabledGroups.contains(command.group)
            let commandOn = !store.disabledCommandIdentifiers.contains(identifier)
            // 실효 활성 규칙의 주인은 store 하나다. 정책은 그 값을 받기만 하고, 둘이 어긋나지 않는지는 여기서 본다.
            let effective = store.isCommandEnabled(identifier, groupToken: command.group.token)
            assert(effective == (groupEnabled && commandOn))
            let shortcut = byIdentifier[identifier]?.shortcut
            let display = ShortcutRowPolicy.decide(ShortcutRowInput(
                shortcutDisplay: shortcut?.displayString,
                hasOverride: overrides[identifier] != nil,
                groupEnabled: groupEnabled,
                commandOn: commandOn,
                effective: effective,
                isConflicting: conflicts.contains(identifier),
                registrationFailed: failures.contains(identifier)
            ))
            next[identifier] = Row(command: command, shortcut: shortcut, display: display)
        }
        rows = next
    }

    // MARK: - List

    func setQuery(_ text: String) {
        query = text
        cancelRecordingIfHidden()
    }

    /// 펼치고 접기. 검색 중에는 펼침이 검색 결과를 따르므로 바꾸지 않는다(검색을 지우면 사용자가 펼친 상태로 돌아간다).
    func toggleExpanded(_ group: CommandGroup) {
        guard !isSearching else { return }
        if expandedGroups.contains(group) { expandedGroups.remove(group) } else { expandedGroups.insert(group) }
        cancelRecordingIfHidden()
    }

    // MARK: - Changes

    func setPreset(_ preset: HotkeyPreset) {
        store.activePreset = preset
        applyChange()
    }

    func resetAll() {
        store.clearAllShortcuts()
        store.commandPaletteShortcut = CommandPaletteShortcut.standard
        applyChange()
    }

    func setCommandPaletteEnabled(_ isOn: Bool) {
        store.commandPaletteEnabled = isOn
        applyChange()
    }

    func resetCommandPalette() {
        store.commandPaletteShortcut = CommandPaletteShortcut.standard
        applyChange()
    }

    func reset(_ command: WindowCommand) {
        store.clearShortcut(forCommand: command.identifier)
        applyChange()
    }

    func setGroupEnabled(_ group: CommandGroup, _ isOn: Bool) {
        store.setGroupDisabled(group.token, disabled: !isOn) // 토큰은 저장 키다. store와 이야기할 때만 쓴다
        applyChange()
    }

    func setCommandEnabled(_ command: WindowCommand, _ isOn: Bool) {
        store.setCommandDisabled(command.identifier, disabled: !isOn)
        applyChange()
    }

    private func applyChange() {
        onHotkeysChanged()
        refresh()
    }

    // MARK: - Recording

    /// 키캡을 눌렀을 때. 전이는 `ShortcutRecordingPolicy`가 정한다.
    func toggleRecording(_ command: WindowCommand) {
        apply(ShortcutRecordingPolicy.toggle(command.identifier, current: recording))
    }

    /// 녹화 칸이 끝을 알릴 때(기록한 조합, 취소면 nil). 그사이 다른 줄로 옮겼으면 무시한다.
    func finishRecording(_ command: WindowCommand, with shortcut: HotkeyShortcut?) {
        guard let step = ShortcutRecordingPolicy.finish(command.identifier, current: recording) else { return }
        apply(step)
        guard let shortcut else { return }
        store.setShortcut(shortcut, forCommand: command.identifier)
        applyChange()
    }

    /// 팔레트 줄의 녹화. 명령 줄과 같은 전이를 팔레트 식별자로 탄다(한 번에 한 줄만 녹화).
    func toggleCommandPaletteRecording() {
        apply(ShortcutRecordingPolicy.toggle(CommandPaletteShortcut.identifier, current: recording))
    }

    func finishCommandPaletteRecording(with shortcut: HotkeyShortcut?) {
        let identifier = CommandPaletteShortcut.identifier
        guard let step = ShortcutRecordingPolicy.finish(identifier, current: recording) else { return }
        apply(step)
        guard let shortcut else { return }
        store.commandPaletteShortcut = shortcut
        applyChange()
    }

    func cancelRecording() {
        guard let recording, let step = ShortcutRecordingPolicy.finish(recording, current: recording) else { return }
        apply(step)
    }

    private func cancelRecordingIfHidden() {
        // 팔레트 줄은 검색·접기와 무관하게 늘 보인다.
        let visible = Set(sections.flatMap(\.rows).map(\.id)).union([CommandPaletteShortcut.identifier])
        if ShortcutRecordingPolicy.isHidden(current: recording, visible: visible) { cancelRecording() }
    }

    private func apply(_ step: ShortcutRecordingStep) {
        recording = step.recording
        if let suspend = step.suspend { setHotkeysSuspended(suspend) }
    }
}
