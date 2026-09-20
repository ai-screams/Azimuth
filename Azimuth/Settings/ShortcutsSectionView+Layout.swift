//
//  ShortcutsSectionView+Layout.swift
//  Azimuth
//
//  ShortcutsSectionView의 레이아웃 구성·검색 필터·접기·프리셋/행 액션. 본문 스크롤은 갖지 않고
//  바깥 페인 스크롤(ShortcutsPaneViewController)에 맡긴다 — 스크롤 중첩을 피한다.
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
        field.setAccessibilityLabel("Filter shortcuts") // placeholder는 VoiceOver 라벨을 보장하지 않는다
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
    ///
    /// 위 간격은 구분선 컨테이너 **안에** 넣는다. 앞 그룹의 마지막 행에 "after" 간격을 걸면 그 행이
    /// 숨을 때(접힘·검색) NSStackView가 간격도 함께 버려 위 6pt/아래 12pt로 어긋난다 — 접힘이 기본
    /// 상태가 되면서 그게 평소 모습이 된다. 컨테이너 여백은 위에 무엇이 보이든 일정하다.
    func addGroupSeparator(for group: CommandGroup, isFirst: Bool) {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)
        container.isHidden = isFirst
        rowsStack.addArrangedSubview(container)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalTo: rowsStack.widthAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.topAnchor.constraint(equalTo: container.topAnchor, constant: Metric.groupGap - Metric.rowSpacing),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        rowsStack.setCustomSpacing(Metric.groupGap, after: container)
        groupSeparators[group.token] = container
    }

    /// 그룹 헤더는 컨트롤 두 개를 나란히 둔다. **의미가 다르므로** 접근성 레이블로 구분한다.
    ///  - 삼각형: 하위 명령 행을 보이거나 감춘다(표시 전용).
    ///  - 체크박스: 그 그룹의 핫키 등록을 켜고 끈다(기능). 접힘과 무관하게 동작한다.
    func addGroupHeader(_ group: CommandGroup) {
        let disclosure = NSButton(title: "", target: self, action: #selector(groupDisclosureToggled(_:)))
        disclosure.bezelStyle = .disclosure
        disclosure.setButtonType(.onOff)
        disclosure.state = .off
        disclosure.setAccessibilityLabel("\(group.displayName) shortcuts") // 펼침/접힘은 disclosure 역할이 전달한다
        groupDisclosures[group.token] = disclosure

        let toggle = NSButton(checkboxWithTitle: group.displayName, target: self, action: #selector(groupToggled(_:)))
        toggle.font = .systemFont(ofSize: Metric.captionFontSize, weight: .bold)
        groupToggles[group.token] = toggle

        let container = NSStackView(views: [disclosure, toggle])
        container.orientation = .horizontal
        container.spacing = 4
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
        reset.setAccessibilityLabel("Reset \(command.displayName) shortcut")

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
        recorder.commandName = command.displayName
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

    /// 검색어와 접힘 상태로 행·헤더·구분선 표시를 정한다. 판정은 `ShortcutListPolicy`가 하고
    /// 여기서는 뷰에 적용만 한다 — 검색과 접힘의 상호작용은 테스트로 고정돼 있다.
    func applyFilter(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)
        let isSearching = !query.isEmpty
        var matchedCounts: [CommandGroup: Int] = [:]
        for row in rows where ShortcutListPolicy.matches(query: query, command: row.command) {
            matchedCounts[row.command.group, default: 0] += 1
        }
        let display = ShortcutListPolicy.display(
            matchedCounts: matchedCounts, isSearching: isSearching, expanded: expandedGroups
        )
        for row in rows {
            let group = display[row.command.group]
            let matched = ShortcutListPolicy.matches(query: query, command: row.command)
            row.container.isHidden = !(matched && group?.isExpanded == true)
        }
        for group in CommandGroup.allCases {
            guard let state = display[group] else { continue }
            groupContainers[group.token]?.isHidden = !state.isHeaderVisible
            groupSeparators[group.token]?.isHidden = !state.isSeparatorVisible
            // 검색 중에는 자동으로 펼쳐지므로 삼각형도 그 상태를 반영해야 어긋나 보이지 않는다.
            // 그 상태는 사용자가 고른 것이 아니므로 검색 중엔 삼각형을 비활성화한다(누르면 모델과 어긋난다).
            groupDisclosures[group.token]?.state = state.isExpanded ? .on : .off
            groupDisclosures[group.token]?.isEnabled = !isSearching
        }
        emptyLabel.isHidden = !matchedCounts.isEmpty || !isSearching
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

    /// 삼각형 토글. 표시만 바꾸고 핫키 등록은 건드리지 않는다(체크박스와 독립).
    ///
    /// 위젯 상태(`sender.state`)가 아니라 모델(`expandedGroups`)을 기준으로 뒤집는다. 검색 중에는
    /// `applyFilter`가 매칭 그룹의 삼각형을 모델과 무관하게 `.on`으로 두므로, 위젯을 믿으면 클릭 한 번이
    /// 모델을 조용히 지우고(검색을 지운 뒤 펼쳐 뒀던 그룹이 접혀 있음) 창까지 다시 맞춘다.
    /// 검색 중에는 삼각형을 비활성화하므로 여기 오지 않지만, 같은 이유로 방어적으로 한 번 더 거른다.
    @objc func groupDisclosureToggled(_ sender: NSButton) {
        guard let token = groupDisclosures.first(where: { $0.value == sender })?.key,
              let group = CommandGroup.allCases.first(where: { $0.token == token })
        else { return }
        let query = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        guard query.isEmpty else {
            applyFilter(query) // 위젯 상태를 정책대로 되돌린다
            return
        }
        if expandedGroups.contains(group) { expandedGroups.remove(group) } else { expandedGroups.insert(group) }
        applyFilter("")
        onExpansionChanged?()
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
