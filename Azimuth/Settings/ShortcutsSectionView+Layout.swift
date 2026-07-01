//
//  ShortcutsSectionView+Layout.swift
//  Azimuth
//
//  ShortcutsSectionView의 레이아웃 구성·검색 필터·프리셋/행 액션. 본문 스크롤은 갖지 않고
//  바깥 설정창 스크롤(ViewController)에 맡긴다 — 스크롤 중첩을 피한다.
//

import Cocoa

extension ShortcutsSectionView {
    func buildLayout() {
        configureRowsStack()

        let hint = NSTextField(
            wrappingLabelWithString: "Click a shortcut to record a new key combo. Esc cancels."
        )
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: Metric.captionFontSize)
        hint.maximumNumberOfLines = 0

        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: Metric.captionFontSize)
        emptyLabel.isHidden = true

        let header = makeHeader()
        let outer = NSStackView(views: [header, searchField, hint, rowsStack, emptyLabel])
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
            header.widthAnchor.constraint(equalTo: outer.widthAnchor),
            searchField.widthAnchor.constraint(equalTo: outer.widthAnchor),
            hint.widthAnchor.constraint(equalTo: outer.widthAnchor),
            rowsStack.widthAnchor.constraint(equalTo: outer.widthAnchor)
        ])

        applyFilter("") // 첫 그룹 구분선 숨김 등 초기 상태 확정.
    }

    func makeHeader() -> NSStackView {
        let caption = NSTextField(labelWithString: "Keymap preset")
        caption.font = .systemFont(ofSize: Metric.captionFontSize, weight: .medium)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let resetAll = NSButton.rounded(title: "Reset All", target: self, action: #selector(resetAll))

        let header = NSStackView(views: [caption, presetControl, spacer, resetAll])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        return header
    }

    func makeSearchField() -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Filter shortcuts"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self
        field.sendsWholeSearchString = false
        field.sendsSearchStringImmediately = true
        return field
    }

    func configureRowsStack() {
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = Metric.rowSpacing
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        // 그룹 사이엔 구분선 + 넓은 간격, 그룹 안 행은 들여쓰기로 위계를 만든다(menuCommands 순서 유지).
        var isFirstGroup = true
        for group in CommandGroup.allCases {
            let commands = WindowCommand.menuCommands.filter { $0.group == group }
            guard !commands.isEmpty else { continue }
            addGroupSeparator(for: group, isFirst: isFirstGroup)
            isFirstGroup = false
            addGroupHeader(group)
            for command in commands {
                rows.append(makeRow(for: command))
            }
        }
    }

    /// 그룹 경계 구분선. 첫 그룹 위에는 두지 않는다(필터링 시 applyFilter가 다시 계산).
    func addGroupSeparator(for group: CommandGroup, isFirst: Bool) {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.isHidden = isFirst
        let previous = rowsStack.arrangedSubviews.last
        rowsStack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
        if let previous { rowsStack.setCustomSpacing(Metric.groupGap, after: previous) }
        rowsStack.setCustomSpacing(Metric.groupGap, after: separator)
        groupSeparators[group.token] = separator
    }

    func addGroupHeader(_ group: CommandGroup) {
        let toggle = NSButton(checkboxWithTitle: group.displayName, target: self, action: #selector(groupToggled(_:)))
        toggle.font = .systemFont(ofSize: Metric.captionFontSize, weight: .bold)
        groupToggles[group.token] = toggle

        let container = NSStackView(views: [toggle])
        container.orientation = .horizontal
        container.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
        groupContainers[group.token] = container
    }

    func makeRow(for command: WindowCommand) -> Row {
        let enable = NSButton(checkboxWithTitle: "", target: self, action: #selector(commandEnableToggled(_:)))
        enable.setAccessibilityLabel("Enable \(command.displayName)")

        let name = NSTextField(labelWithString: command.displayName)
        name.lineBreakMode = .byTruncatingTail
        name.toolTip = command.helpText // 무엇을 하는 명령인지 hover로 설명(학습성).

        let dot = makeModifiedDot()
        let gutter = makeIndentGutter(dot: dot)
        let recorder = makeRecorder(for: command)

        let reset = NSButton.rounded(title: "Reset", target: self, action: #selector(resetRow(_:)))

        let badge = BadgeLabel()
        badge.isHidden = true
        badge.setContentHuggingPriority(.defaultLow, for: .horizontal)
        badge.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // 거터(들여쓰기) → 활성 체크 → 이름 → 단축키 → Reset → 배지. 앞 3개가 고정폭이라 단축키 컬럼이 정렬된다.
        let container = NSStackView(views: [gutter, enable, name, recorder, reset, badge])
        container.orientation = .horizontal
        container.alignment = .centerY
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
            command: command, container: container, nameLabel: name, enableCheckbox: enable,
            recorder: recorder, resetButton: reset, modifiedDot: dot, badge: badge
        )
    }

    private func makeRecorder(for command: WindowCommand) -> ShortcutRecorderButton {
        let recorder = ShortcutRecorderButton()
        recorder.onCapture = { [weak self] shortcut in self?.capture(shortcut, for: command) }
        // 녹화 중에는 전역 핫키를 일시 정지해, 녹화하려는 조합이 백그라운드 창을 조작하지 않게 한다.
        recorder.onRecordingStateChanged = { [weak self] recording in self?.setHotkeysSuspended(recording) }
        return recorder
    }

    /// 기본값과 다른 명령을 표시하는 작은 액센트 점.
    private func makeModifiedDot() -> NSView {
        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        dot.layer?.cornerRadius = Metric.dotSize / 2
        dot.toolTip = "Customized — differs from the preset default."
        dot.isHidden = true
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: Metric.dotSize),
            dot.heightAnchor.constraint(equalToConstant: Metric.dotSize)
        ])
        return dot
    }

    /// 하위 행을 그룹 헤더 아래로 들여쓰는 고정폭 좌측 거터. 변경 점(•)을 그 안에 띄워
    /// 점의 표시 여부와 무관하게 단축키 컬럼 정렬이 유지되게 한다.
    private func makeIndentGutter(dot: NSView) -> NSView {
        let gutter = NSView()
        gutter.translatesAutoresizingMaskIntoConstraints = false
        gutter.addSubview(dot)
        NSLayoutConstraint.activate([
            gutter.widthAnchor.constraint(equalToConstant: Metric.indent),
            gutter.heightAnchor.constraint(equalToConstant: Metric.rowHeight),
            dot.centerXAnchor.constraint(equalTo: gutter.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: gutter.centerYAnchor)
        ])
        return gutter
    }

    func makePresetControl() -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: HotkeyPreset.allCases.map(\.displayName),
            trackingMode: .selectOne,
            target: self,
            action: #selector(presetChanged(_:))
        )
        if let index = HotkeyPreset.allCases.firstIndex(of: preferencesStore.activePreset) {
            control.selectedSegment = index
        }
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }

    /// 검색어로 행·그룹 헤더·구분선 표시를 토글한다(빈 검색이면 모두 표시).
    /// 구분선은 "보이는 그룹들 사이"에만 둔다 — 첫 보이는 그룹 위에는 두지 않는다.
    func applyFilter(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespaces).lowercased()
        var anyVisible = false
        var seenVisibleGroup = false
        for group in CommandGroup.allCases {
            let groupRows = rows.filter { $0.command.group == group }
            guard !groupRows.isEmpty else { continue }
            var groupVisible = false
            for row in groupRows {
                let match = query.isEmpty
                    || row.command.displayName.lowercased().contains(query)
                    || group.displayName.lowercased().contains(query)
                row.container.isHidden = !match
                if match {
                    groupVisible = true
                    anyVisible = true
                }
            }
            groupContainers[group.token]?.isHidden = !groupVisible
            groupSeparators[group.token]?.isHidden = !(groupVisible && seenVisibleGroup)
            if groupVisible { seenVisibleGroup = true }
        }
        emptyLabel.isHidden = anyVisible || query.isEmpty
    }

    func capture(_ shortcut: HotkeyShortcut, for command: WindowCommand) {
        preferencesStore.setShortcut(shortcut, forCommand: command.identifier)
        onHotkeysChanged()
        refresh()
    }

    @objc func presetChanged(_ sender: NSSegmentedControl) {
        let presets = HotkeyPreset.allCases
        guard presets.indices.contains(sender.selectedSegment) else { return }
        preferencesStore.activePreset = presets[sender.selectedSegment]
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
