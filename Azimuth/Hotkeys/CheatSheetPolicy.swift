//
//  CheatSheetPolicy.swift
//  Azimuth
//
//  단축키 치트시트(#182)의 판단을 값으로: 키보드 지도에 그릴 키, 누르고 있는 수정키 조합 한 층의 명령,
//  수정키를 누르고 떼는 흐름에서 언제 띄우고 닫을지. 패널과 이벤트 감시는 이 결과를 실행만 한다.
//

nonisolated enum CheatSheetKeyboard {
    /// 자판의 키 하나. `keyCode`가 nil이면 이름 없는 키(Tab, Caps Lock, Shift 자리)라 흐린 빈 칸으로 그린다.
    /// `units`는 보통 키 너비의 배수, nil이면 그 줄의 남는 너비를 모두 채운다(줄마다 한 키).
    struct Key: Equatable {
        let keyCode: UInt32?
        let units: Double?
    }

    private static func keys(_ codes: [UInt32]) -> [Key] {
        codes.map { Key(keyCode: $0, units: 1) }
    }

    /// U.S. 배열, 위 줄부터. 줄 끝을 맞추려고 실제 자판처럼 Delete·Return·Shift·Space가 남는 너비를 채운다.
    /// Return(최대화)과 Delete(Undo)는 가장 많이 쓰는 명령이라 지도에 꼭 있어야 한다.
    static let rows: [[Key]] = [
        keys([0x32, 0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19, 0x1D, 0x1B, 0x18])
            + [Key(keyCode: 0x33, units: nil)],
        [Key(keyCode: nil, units: 1.5)]
            + keys([0x0C, 0x0D, 0x0E, 0x0F, 0x11, 0x10, 0x20, 0x22, 0x1F, 0x23, 0x21, 0x1E])
            + [Key(keyCode: 0x2A, units: nil)],
        [Key(keyCode: nil, units: 1.75)]
            + keys([0x00, 0x01, 0x02, 0x03, 0x05, 0x04, 0x26, 0x28, 0x25, 0x29, 0x27])
            + [Key(keyCode: 0x24, units: nil)],
        [Key(keyCode: nil, units: 2.25)]
            + keys([0x06, 0x07, 0x08, 0x09, 0x0B, 0x2D, 0x2E, 0x2B, 0x2F, 0x2C])
            + [Key(keyCode: nil, units: nil)],
        [Key(keyCode: 0x31, units: nil)] + keys([0x7B, 0x7E, 0x7D, 0x7C])
    ]

    static let keyCodes = Set(rows.joined().compactMap(\.keyCode))

    /// 자판 너비(키 너비 배수): 맨 위 줄에서 Delete를 1.5로 본 너비.
    static let widthUnits = 14.5

    /// 줄마다 키 너비(pt). 모든 줄의 합(키 + 간격)이 같아 오른쪽 끝이 맞는다.
    static func widths(unit: Double, spacing: Double) -> [[Double]] {
        let total = widthUnits * unit + Double(rows[0].count - 1) * spacing
        return rows.map { row in
            let fixed = row.compactMap(\.units).reduce(0, +) * unit + Double(row.count - 1) * spacing
            return row.map { $0.units.map { $0 * unit } ?? total - fixed }
        }
    }
}

/// 누르고 있는 수정키 조합 하나의 명령들. 수정키가 정확히 같은 바인딩만 들어간다(⌃⌥와 ⌃⌥⇧는 다른 층).
nonisolated struct CheatSheetLayer: Equatable {
    let modifiers: UInt32
    /// 지도 위 키 → 명령.
    let mapped: [UInt32: WindowCommand]
    /// 지도에 없는 키(F키 등 사용자 지정). 패널 아래 줄에 따로 보인다.
    let others: [HotkeyShortcutCommand]

    /// 그 조합의 바인딩이 하나도 없으면 nil. 글자를 치며 ⇧만 누르는 것처럼 명령과 상관없는 수정키는 아무것도 띄우지 않는다.
    static func make(bindings: [HotkeyBinding], modifiers: UInt32) -> Self? {
        let layer = bindings.filter { $0.modifiers == modifiers }
        guard !layer.isEmpty else { return nil }
        var mapped: [UInt32: WindowCommand] = [:]
        var others: [HotkeyShortcutCommand] = []
        for binding in layer {
            if CheatSheetKeyboard.keyCodes.contains(binding.keyCode) {
                mapped[binding.keyCode] = binding.command
            } else {
                others.append(HotkeyShortcutCommand(shortcut: binding.shortcut, command: binding.command))
            }
        }
        return Self(modifiers: modifiers, mapped: mapped, others: others)
    }

    /// 층 이름: 이 층에 있는 명령 그룹을 `CommandGroup` 순서로 이은 것(예: "Halves · Thirds").
    var title: String {
        let groups = Set((Array(mapped.values) + others.map(\.command)).map(\.group))
        return CommandGroup.allCases.filter { groups.contains($0) }.map(\.displayName).joined(separator: " · ")
    }
}

nonisolated struct HotkeyShortcutCommand: Equatable {
    let shortcut: HotkeyShortcut
    let command: WindowCommand
}

/// 수정키를 누르고 있는 동안의 흐름. 이벤트 하나 → (다음 상태, 할 일).
nonisolated enum CheatSheetTrigger {
    enum State: Equatable {
        case idle
        /// 층이 있는 조합을 누르기 시작함. 지연이 지나면 띄운다.
        case pending(UInt32)
        case shown(UInt32)
        /// 그 조합으로 키를 눌렀다(명령 실행 등). 조합이 바뀌거나 떼기 전까지 다시 띄우지 않는다.
        case suppressed(UInt32)
    }

    enum Event: Equatable {
        /// 수정키가 바뀜. `hasLayer`는 그 조합에 바인딩이 있는지(`CheatSheetLayer.make != nil`).
        case modifiers(UInt32, hasLayer: Bool)
        /// 수정키가 아닌 키가 눌렸거나 명령이 실행됨.
        case keyPressed
        case delayElapsed
    }

    enum Effect: Equatable {
        case none
        case schedule
        case cancel
        case show(UInt32)
        case hide
    }

    static func reduce(_ state: State, _ event: Event) -> (State, Effect) {
        switch event {
        case let .modifiers(mask, hasLayer):
            modifiersChanged(state, mask: mask, hasLayer: hasLayer)
        case .keyPressed:
            switch state {
            case let .pending(mask):
                (.suppressed(mask), .cancel)
            case let .shown(mask):
                (.suppressed(mask), .hide)
            case .idle, .suppressed:
                (state, .none)
            }
        case .delayElapsed:
            if case let .pending(mask) = state { (.shown(mask), .show(mask)) } else { (state, .none) }
        }
    }

    private static func modifiersChanged(_ state: State, mask: UInt32, hasLayer: Bool) -> (State, Effect) {
        guard hasLayer else {
            switch state {
            case .shown:
                return (.idle, .hide)
            case .pending:
                return (.idle, .cancel)
            case .idle, .suppressed:
                return (.idle, .none)
            }
        }
        switch state {
        case .shown:
            return (.shown(mask), .show(mask))
        case let .suppressed(held) where held == mask:
            return (state, .none)
        case .idle, .pending, .suppressed:
            return (.pending(mask), .schedule)
        }
    }
}

/// 수정키를 누르고 기다리는 시간(설정 General). 저장은 밀리초 정수이고, 손으로 바꾼 값이나 모르는 값은 기본으로 읽는다.
nonisolated enum CheatSheetDelay: Int, CaseIterable {
    case short = 500
    case standard = 800
    case long = 1200

    var seconds: Double {
        Double(rawValue) / 1000
    }

    var displayName: String {
        switch self {
        case .short:
            "0.5 seconds"
        case .standard:
            "0.8 seconds"
        case .long:
            "1.2 seconds"
        }
    }

    /// 저장 값 → 선택지. 없거나(첫 실행) 선택지에 없으면 `.standard`.
    static func stored(_ milliseconds: Int?) -> Self {
        milliseconds.flatMap(Self.init(rawValue:)) ?? .standard
    }
}
