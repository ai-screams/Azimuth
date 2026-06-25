//
//  ShortcutsSectionView.swift
//  Azimuth
//
//  Shortcuts 설정 섹션 본문: 프리셋 선택 + 명령별 단축키 레코더 목록 + 충돌/점유 경고.
//

import Cocoa

@MainActor
final class ShortcutsSectionView: NSView {
    private enum Metric {
        static let rowHeight: CGFloat = 26
        static let nameWidth: CGFloat = 150
        static let recorderWidth: CGFloat = 120
        static let resetWidth: CGFloat = 56
        static let listHeight: CGFloat = 220
        static let captionFontSize: CGFloat = 13
        static let rowSpacing: CGFloat = 6
    }

    private let preferencesStore: PreferencesStore
    private let onHotkeysChanged: () -> Void
    private let registrationFailures: () -> Set<String>
    private let setHotkeysSuspended: (Bool) -> Void

    private lazy var presetPopUp = makePresetPopUp()
    private let rowsStack = NSStackView()
    private var rows: [Row] = []
    private var groupToggles: [String: NSButton] = [:]

    struct Row {
        let command: WindowCommand
        let nameLabel: NSTextField
        let enableCheckbox: NSButton
        let recorder: ShortcutRecorderButton
        let resetButton: NSButton
        let warningLabel: NSTextField
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
        let warning = effective ? warningText(for: identifier, conflicts: conflicts, failures: failures) : ""
        apply(warning: warning, to: row.warningLabel)
    }

    /// 내부 중복을 시스템 점유보다 우선 표시한다(중복이면 둘 다 등록 실패할 수 있어 메시지가 엇갈리지 않게).
    private func warningText(for identifier: String, conflicts: Set<String>, failures: Set<String>) -> String {
        if conflicts.contains(identifier) { return "Duplicate" }
        if failures.contains(identifier) { return "In use by system" }
        return ""
    }

    private func apply(warning: String, to label: NSTextField) {
        label.stringValue = warning
        label.toolTip = warning.isEmpty ? nil : "\(warning) — this shortcut won't trigger this command."
        label.isHidden = warning.isEmpty
    }
}

private extension ShortcutsSectionView {
    func buildLayout() {
        configureRowsStack()
        let scroll = makeScrollView()
        let hint = NSTextField(
            wrappingLabelWithString: "Click a shortcut to record a new key combo. Esc cancels."
        )
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: Metric.captionFontSize)
        hint.maximumNumberOfLines = 0

        let outer = NSStackView(views: [makeHeader(), hint, scroll])
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = Metric.rowSpacing
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)

        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor),
            outer.topAnchor.constraint(equalTo: topAnchor),
            outer.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.widthAnchor.constraint(equalTo: outer.widthAnchor),
            scroll.heightAnchor.constraint(equalToConstant: Metric.listHeight)
        ])
    }

    func makeHeader() -> NSStackView {
        let caption = NSTextField(labelWithString: "Keymap preset")
        caption.font = .systemFont(ofSize: Metric.captionFontSize, weight: .medium)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let resetAll = NSButton(title: "Reset All", target: self, action: #selector(resetAll))
        resetAll.bezelStyle = .rounded

        let header = NSStackView(views: [caption, presetPopUp, spacer, resetAll])
        header.orientation = .horizontal
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        return header
    }

    func makeScrollView() -> NSScrollView {
        // documentView는 flipped여야 행이 위에서 아래로(Maximize가 맨 위) 쌓이고 스크롤 시작이 상단이 된다.
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rowsStack)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = document
        NSLayoutConstraint.activate([
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            rowsStack.topAnchor.constraint(equalTo: document.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: document.bottomAnchor)
        ])
        return scroll
    }

    func configureRowsStack() {
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = Metric.rowSpacing
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        // 그룹 헤더 + 그 그룹에 속한 명령 행을 차례로 쌓는다(menuCommands 순서 유지).
        for group in CommandGroup.allCases {
            let commands = WindowCommand.menuCommands.filter { $0.group == group }
            guard !commands.isEmpty else { continue }
            addGroupHeader(group)
            for command in commands {
                rows.append(makeRow(for: command))
            }
        }
    }

    func addGroupHeader(_ group: CommandGroup) {
        let toggle = NSButton(checkboxWithTitle: group.displayName, target: self, action: #selector(groupToggled(_:)))
        toggle.font = .systemFont(ofSize: Metric.captionFontSize, weight: .semibold)
        groupToggles[group.token] = toggle

        let container = NSStackView(views: [toggle])
        container.orientation = .horizontal
        container.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
    }

    func makeRow(for command: WindowCommand) -> Row {
        let enable = NSButton(checkboxWithTitle: "", target: self, action: #selector(commandEnableToggled(_:)))
        enable.setAccessibilityLabel("Enable \(command.displayName)")

        let name = NSTextField(labelWithString: command.displayName)
        name.lineBreakMode = .byTruncatingTail

        let warning = NSTextField(labelWithString: "")
        warning.textColor = .systemOrange
        warning.font = .systemFont(ofSize: Metric.captionFontSize)
        warning.lineBreakMode = .byTruncatingTail
        warning.isHidden = true
        // 경고는 행 끝에서 남는 공간을 채우되, 좁으면 잘리게 해 고정폭 컨트롤을 밀어내지 않는다.
        warning.setContentHuggingPriority(.defaultLow, for: .horizontal)
        warning.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let recorder = ShortcutRecorderButton()
        recorder.onCapture = { [weak self] shortcut in self?.capture(shortcut, for: command) }
        // 녹화 중에는 전역 핫키를 일시 정지해, 녹화하려는 조합이 백그라운드 창을 조작하지 않게 한다.
        recorder.onRecordingStateChanged = { [weak self] recording in self?.setHotkeysSuspended(recording) }

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetRow(_:)))
        reset.bezelStyle = .rounded

        let container = NSStackView(views: [enable, name, recorder, reset, warning])
        container.orientation = .horizontal
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.addArrangedSubview(container)

        NSLayoutConstraint.activate([
            name.widthAnchor.constraint(equalToConstant: Metric.nameWidth),
            recorder.widthAnchor.constraint(equalToConstant: Metric.recorderWidth),
            reset.widthAnchor.constraint(equalToConstant: Metric.resetWidth),
            container.heightAnchor.constraint(equalToConstant: Metric.rowHeight),
            container.widthAnchor.constraint(equalTo: rowsStack.widthAnchor)
        ])
        return Row(
            command: command,
            nameLabel: name,
            enableCheckbox: enable,
            recorder: recorder,
            resetButton: reset,
            warningLabel: warning
        )
    }

    func makePresetPopUp() -> NSPopUpButton {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        for preset in HotkeyPreset.allCases {
            popUp.addItem(withTitle: preset.displayName)
            popUp.lastItem?.representedObject = preset
        }
        if let index = HotkeyPreset.allCases.firstIndex(of: preferencesStore.activePreset) {
            popUp.selectItem(at: index)
        }
        popUp.target = self
        popUp.action = #selector(presetChanged(_:))
        return popUp
    }

    func capture(_ shortcut: HotkeyShortcut, for command: WindowCommand) {
        preferencesStore.setShortcut(shortcut, forCommand: command.identifier)
        onHotkeysChanged()
        refresh()
    }

    @objc func presetChanged(_ sender: NSPopUpButton) {
        guard let preset = sender.selectedItem?.representedObject as? HotkeyPreset else { return }
        preferencesStore.activePreset = preset
        onHotkeysChanged()
        refresh()
    }

    @objc func resetRow(_ sender: NSButton) {
        guard let row = rows.first(where: { $0.resetButton == sender }) else { return }
        preferencesStore.clearShortcut(forCommand: row.command.identifier)
        onHotkeysChanged()
        refresh()
    }

    @objc func resetAll() {
        preferencesStore.clearAllShortcuts()
        onHotkeysChanged()
        refresh()
    }

    @objc func groupToggled(_ sender: NSButton) {
        guard let token = groupToggles.first(where: { $0.value == sender })?.key else { return }
        preferencesStore.setGroupDisabled(token, disabled: sender.state == .off)
        onHotkeysChanged()
        refresh()
    }

    @objc func commandEnableToggled(_ sender: NSButton) {
        guard let row = rows.first(where: { $0.enableCheckbox == sender }) else { return }
        preferencesStore.setCommandDisabled(row.command.identifier, disabled: sender.state == .off)
        onHotkeysChanged()
        refresh()
    }
}

/// 위에서 아래로 콘텐츠를 쌓기 위한 flipped 컨테이너(NSScrollView documentView용).
private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
