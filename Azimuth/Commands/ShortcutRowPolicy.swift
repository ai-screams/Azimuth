//
//  ShortcutRowPolicy.swift
//  Azimuth
//
//  단축키 목록에서 행 하나가 어떻게 보일지 정하는 순수 판정. 레코더 문자열·체크박스 두 축·
//  Reset 활성·이름 흐림·변경 점·배지까지 관측 가능한 여덟 가지가 값 여섯에서 나온다.
//
//  뷰에서 분리한 이유는 배지 우선순위다 — 내부 중복과 시스템 점유가 동시에 성립할 때 무엇을
//  보여주는가가 사용자 안내를 좌우하는데(중복인데 "시스템 점유"라고 하면 다른 조합을 찾아 헤맨다),
//  그 판정이 NSButton·NSColor 를 직접 만지는 메서드 안에 있어 하네스가 닿지 못했다.
//
//  ⚠️ 순수 로직 파일 — AppKit/AX를 import하지 말 것. 이 파일은 Foundation 도 필요 없다
//  (전부 Bool·String). 새 순수 파일은 scripts/harness-sources.sh 에 추가해야 컴파일된다.
//

/// 행 하나의 표시를 정하는 데 필요한 값 전부.
nonisolated struct ShortcutRowInput: Equatable {
    /// 이 명령에 실제로 묶인 단축키의 표시 문자열. 바인딩이 없으면 nil.
    let shortcutDisplay: String?
    /// 사용자가 프리셋 기본값에서 바꿨는가.
    let hasOverride: Bool
    /// 이 명령이 속한 그룹이 켜져 있는가. 체크박스를 **누를 수 있는지**를 정한다.
    let groupEnabled: Bool
    /// 이 명령 자체의 체크 상태(그룹과 무관). 체크박스의 on/off 다.
    let commandOn: Bool
    /// 실효 활성. **여기서 재결합하지 않고 값으로 받는다** — 규칙의 주인은
    /// `PreferencesStore.isCommandEnabled` 하나여야 하고, 식을 두 곳에 두면 갈라진다.
    let effective: Bool
    /// 같은 조합을 쓰는 활성 명령이 둘 이상인가.
    let isConflicting: Bool
    /// 등록이 실패했는가. 문구는 "In use by system"이지만 실제 의미는 "등록 실패"다
    /// (`Hotkeys/HotkeyService`의 주석 참고).
    let registrationFailed: Bool
}

/// 배지는 **의미**만 정하고 문구·기호·색은 뷰가 고른다 — 순수 계층은 AppKit 을 모른다.
nonisolated enum ShortcutRowBadge: Equatable {
    case none
    /// 내부 중복. 점유보다 **우선** 표시한다 — 중복이면 둘 다 등록에 실패할 수 있어
    /// 두 메시지가 엇갈린다.
    case duplicate
    /// 등록 실패(시스템이 이미 쓰는 조합 등).
    case systemOccupied
}

nonisolated struct ShortcutRowDisplay: Equatable {
    /// 레코더 버튼의 idle 표시. 바인딩이 있으면 **꺼진 명령이어도** 그대로 보여준다
    /// (흐리게 그려질 뿐 문자열은 남는다).
    let shortcutText: String
    let checkboxOn: Bool
    let checkboxEnabled: Bool
    let recorderEnabled: Bool
    let resetEnabled: Bool
    /// 이름을 흐리게 그릴지(뷰가 `.labelColor`/`.disabledControlTextColor` 로 옮긴다).
    let isDimmed: Bool
    let showsModifiedDot: Bool
    let badge: ShortcutRowBadge
}

nonisolated enum ShortcutRowPolicy {
    static func decide(_ input: ShortcutRowInput) -> ShortcutRowDisplay {
        ShortcutRowDisplay(
            shortcutText: input.shortcutDisplay ?? "",
            checkboxOn: input.commandOn,
            // 그룹이 꺼져 있으면 명령별 체크는 의미가 없다 — 켜고 꺼도 등록되지 않으므로 잠근다.
            // 실효 활성이 아니라 **그룹**이 기준이다: 그룹이 켜져 있고 명령만 꺼진 상태에서는
            // 다시 켤 수 있어야 한다.
            checkboxEnabled: input.groupEnabled,
            recorderEnabled: input.effective,
            // 되돌릴 것이 있을 때만 Reset 이 의미가 있다.
            resetEnabled: input.effective && input.hasOverride,
            isDimmed: !input.effective,
            showsModifiedDot: input.effective && input.hasOverride,
            badge: badge(for: input)
        )
    }

    private static func badge(for input: ShortcutRowInput) -> ShortcutRowBadge {
        // 등록되지 않는 단축키의 경고는 소음이다 — 꺼진 명령에는 배지를 달지 않는다.
        guard input.effective else { return .none }
        if input.isConflicting { return .duplicate }
        if input.registrationFailed { return .systemOccupied }
        return .none
    }
}
