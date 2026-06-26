//
//  ShortcutsSectionView.swift
//  Azimuth
//
//  Shortcuts 설정 섹션 본문: 프리셋 선택(세그먼트) + 검색 필터 + 명령별 단축키
//  레코더 목록 + 변경 점(•) + 충돌/점유 배지. 레이아웃·액션은 +Layout 확장 파일에 둔다.
//

import Cocoa

@MainActor
final class ShortcutsSectionView: NSView {
    enum Metric {
        static let rowHeight: CGFloat = 26
        static let nameWidth: CGFloat = 150
        static let recorderWidth: CGFloat = 120
        static let resetWidth: CGFloat = 56
        static let captionFontSize: CGFloat = 13
        static let rowSpacing: CGFloat = 6
        static let dotSize: CGFloat = 6
    }

    let preferencesStore: PreferencesStore
    let onHotkeysChanged: () -> Void
    let registrationFailures: () -> Set<String>
    let setHotkeysSuspended: (Bool) -> Void

    lazy var presetControl = makePresetControl()
    lazy var searchField = makeSearchField()
    let rowsStack = NSStackView()
    var rows: [Row] = []
    var groupToggles: [String: NSButton] = [:]
    var groupContainers: [String: NSView] = [:]
    let emptyLabel = NSTextField(labelWithString: "No shortcuts match your search.")

    struct Row {
        let command: WindowCommand
        let container: NSView
        let nameLabel: NSTextField
        let enableCheckbox: NSButton
        let recorder: ShortcutRecorderButton
        let resetButton: NSButton
        let modifiedDot: NSView
        let badge: BadgeLabel
    }

    init(
        preferencesStore: PreferencesStore,
        onHotkeysChanged: @escaping () -> Void,
        registrationFailures: @escaping () -> Set<String>,
        setHotkeysSuspended: @escaping (Bool) -> Void
    ) {
        self.preferencesStore = preferencesStore
        self.onHotkeysChanged = onHotkeysChanged
        self.registrationFailures = registrationFailures
        self.setHotkeysSuspended = setHotkeysSuspended
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildLayout()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 실효 바인딩·활성 상태·충돌·등록 실패를 다시 계산해 그룹 토글과 각 행을 갱신한다.
    func refresh() {
        let overrides = preferencesStore.customShortcuts
        let bindings = BindingResolver.resolve(preset: preferencesStore.activePreset, overrides: overrides)
        let byIdentifier = Dictionary(
            bindings.map { ($0.command.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // 충돌·등록 실패는 실제 등록되는 활성 바인딩에만 의미가 있다.
        let enabledBindings = BindingResolver.enabled(
            bindings,
            disabledCommands: preferencesStore.disabledCommandIdentifiers,
            disabledGroups: preferencesStore.disabledGroupTokens
        )
        let conflicts = BindingResolver.conflictingIdentifiers(in: enabledBindings)
        let failures = registrationFailures()

        for (token, toggle) in groupToggles {
            toggle.state = preferencesStore.isGroupEnabled(token) ? .on : .off
        }
        for row in rows {
            updateRow(row, binding: byIdentifier[row.command.identifier],
                      hasOverride: overrides[row.command.identifier] != nil,
                      conflicts: conflicts, failures: failures)
        }
    }

    private func updateRow(
        _ row: Row,
        binding: HotkeyBinding?,
        hasOverride: Bool,
        conflicts: Set<String>,
        failures: Set<String>
    ) {
        let identifier = row.command.identifier
        let groupToken = row.command.group.token
        let groupEnabled = preferencesStore.isGroupEnabled(groupToken)
        let commandOn = !preferencesStore.disabledCommandIdentifiers.contains(identifier)
        // 실효 활성 판정은 store의 단일 규칙(isCommandEnabled)에 위임한다.
        let effective = preferencesStore.isCommandEnabled(identifier, groupToken: groupToken)

        if let binding {
            let shortcut = HotkeyShortcut(keyCode: binding.keyCode, modifiers: binding.modifiers)
            row.recorder.setIdleDisplay(shortcut.displayString)
        } else {
            row.recorder.setIdleDisplay("")
        }
        row.enableCheckbox.state = commandOn ? .on : .off
        row.enableCheckbox.isEnabled = groupEnabled
        row.recorder.isEnabled = effective
        row.resetButton.isEnabled = effective && hasOverride
        row.nameLabel.textColor = effective ? .labelColor : .disabledControlTextColor
        // 기본값과 다른(사용자가 바꾼) 명령엔 점(•)을 표시한다.
        row.modifiedDot.isHidden = !(effective && hasOverride)
        updateBadge(for: row, effective: effective, conflicts: conflicts, failures: failures)
    }

    /// 내부 중복을 시스템 점유보다 우선 표시한다(중복이면 둘 다 등록 실패할 수 있어 메시지가 엇갈리지 않게).
    private func updateBadge(for row: Row, effective: Bool, conflicts: Set<String>, failures: Set<String>) {
        let identifier = row.command.identifier
        guard effective else {
            row.badge.isHidden = true
            return
        }
        if conflicts.contains(identifier) {
            row.badge.configure(text: "Duplicate", symbol: "exclamationmark.triangle.fill", color: .systemRed)
            row.badge.isHidden = false
        } else if failures.contains(identifier) {
            row.badge.configure(text: "In use by system", symbol: "exclamationmark.octagon.fill", color: .systemOrange)
            row.badge.isHidden = false
        } else {
            row.badge.isHidden = true
        }
    }
}

extension ShortcutsSectionView: NSSearchFieldDelegate {
    /// 검색어가 바뀔 때마다 행/그룹 헤더 표시를 갱신한다.
    func controlTextDidChange(_ obj: Notification) {
        applyFilter(searchField.stringValue)
    }
}
