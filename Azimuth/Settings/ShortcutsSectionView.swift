//
//  ShortcutsSectionView.swift
//  Azimuth
//
//  Shortcuts 설정 섹션 본문: 프리셋 선택(세그먼트) + 검색 필터 + 명령별 단축키
//  레코더 목록 + 변경 점(•) + 충돌/점유 배지. 그룹은 삼각형으로 접고 펼친다(기본 접힘).
//  레이아웃·액션은 +Layout 확장 파일에 둔다.
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
        /// 하위 명령 행 들여쓰기 폭(겸 변경 점이 놓이는 좌측 거터). 고정폭이라 컬럼 정렬이 흔들리지 않는다.
        static let indent: CGFloat = 22
        /// 그룹 경계(구분선) 위아래 간격.
        static let groupGap: CGFloat = 12
    }

    let preferencesStore: PreferencesStore
    let onHotkeysChanged: () -> Void
    let registrationFailures: () -> Set<String>
    let setHotkeysSuspended: (Bool) -> Void

    lazy var presetControl = makePresetControl()
    lazy var searchField = makeSearchField()
    let rowsStack = NSStackView()
    var rows: [Row] = []
    /// 그룹 하나를 이루는 뷰 넷. 따로 딕셔너리 넷으로 두면 같은 키 집합을 유지한다는 보장이 없고,
    /// 역조회가 `String` 토큰을 경유해 두 번 건너뛰게 된다. 토큰은 저장 키이므로
    /// `PreferencesStore` 와 이야기할 때만 쓴다.
    var groupViews: [CommandGroup: GroupViews] = [:]
    /// 사용자가 삼각형으로 펼친 그룹. **저장하지 않는다** — 창을 열 때마다 전부 접힘으로
    /// 시작해야 창 높이가 예측 가능하고, 저장 키와 마이그레이션이 늘지 않는다.
    var expandedGroups: Set<CommandGroup> = []
    let emptyLabel = NSTextField(labelWithString: "No shortcuts match your search.")

    struct GroupViews {
        /// 핫키 등록을 켜고 끄는 체크박스(기능).
        let toggle: NSButton
        /// 삼각형 — 하위 행 표시만 바꾼다(표시). 체크박스와 독립이다.
        let disclosure: NSButton
        /// 헤더 행 컨테이너(체크박스 + 삼각형).
        let header: NSView
        /// 이 그룹 **위** 구분선(위 여백을 품은 컨테이너). 첫 보이는 그룹 위에는 숨긴다.
        let separator: NSView
    }

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

    /// 창을 열 때마다 전부 접힘으로 되돌린다. 상태를 저장하지 않으므로 창 높이가 항상 예측 가능하다.
    /// 검색어도 지운다 — 남아 있으면 매칭 그룹이 자동으로 펼쳐져 "전부 접힘"이 아니게 된다.
    /// 행 스택의 전체 슬롯(구분선·그룹 머리·행)을 원래 순서로 기억한다. 숨은 슬롯은 계층에서 떼어
    /// 접힌 행 수백 개가 탭 교체 때마다 배치·키 뷰 루프 계산에 끼지 않게 한다(`pruneHiddenSlots`).
    var allSlots: [NSView] = []

    func collapseAllGroups() {
        expandedGroups.removeAll()
        searchField.stringValue = ""
        applyFilter("")
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

        for (group, views) in groupViews {
            views.toggle.state = preferencesStore.isGroupEnabled(group.token) ? .on : .off
        }
        for row in rows {
            updateRow(row, binding: byIdentifier[row.command.identifier],
                      hasOverride: overrides[row.command.identifier] != nil,
                      conflicts: conflicts, failures: failures)
        }
    }

    /// 표시 판정은 `ShortcutRowPolicy`(순수)가 하고 여기서는 위젯에 꽂기만 한다 — 여덟 가지 출력의
    /// 진리표, 특히 배지 우선순위를 하네스에서 전수 검증하기 위해서다.
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
        // 실효 활성 판정의 주인은 store 의 단일 규칙이다. 정책은 그 값을 받기만 한다 —
        // 같은 식을 정책에도 두면 출처가 둘이 된다. 그 둘이 어긋나지 않는지 확인할 수 있는
        // 유일한 지점이 여기다(하네스에는 store 가 없다).
        let effective = preferencesStore.isCommandEnabled(identifier, groupToken: groupToken)
        assert(effective == (groupEnabled && commandOn))

        let display = ShortcutRowPolicy.decide(ShortcutRowInput(
            shortcutDisplay: binding.map { HotkeyShortcut(keyCode: $0.keyCode, modifiers: $0.modifiers).displayString },
            hasOverride: hasOverride,
            groupEnabled: groupEnabled,
            commandOn: commandOn,
            effective: effective,
            isConflicting: conflicts.contains(identifier),
            registrationFailed: failures.contains(identifier)
        ))
        apply(display, to: row)
    }

    private func apply(_ display: ShortcutRowDisplay, to row: Row) {
        row.recorder.setIdleDisplay(display.shortcutText)
        row.enableCheckbox.state = display.checkboxOn ? .on : .off
        row.enableCheckbox.isEnabled = display.checkboxEnabled
        row.recorder.isEnabled = display.recorderEnabled
        row.resetButton.isEnabled = display.resetEnabled
        row.nameLabel.textColor = display.isDimmed ? .disabledControlTextColor : .labelColor
        row.modifiedDot.isHidden = !display.showsModifiedDot
        switch display.badge {
        case .none:
            row.badge.isHidden = true
        case .duplicate:
            row.badge.configure(text: "Duplicate", symbol: "exclamationmark.triangle.fill", color: .systemRed)
            row.badge.isHidden = false
        case .systemOccupied:
            row.badge.configure(text: "In use by system", symbol: "exclamationmark.octagon.fill", color: .systemOrange)
            row.badge.isHidden = false
        }
    }
}

extension ShortcutsSectionView: NSSearchFieldDelegate {
    /// 검색어가 바뀔 때마다 행/그룹 헤더 표시를 갱신한다.
    func controlTextDidChange(_ obj: Notification) {
        applyFilter(searchField.stringValue)
    }
}
