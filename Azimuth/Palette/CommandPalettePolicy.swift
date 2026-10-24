//
//  CommandPalettePolicy.swift
//  Azimuth
//
//  명령 팔레트(#183)의 판단을 값으로: 검색어에 걸리는 명령과 순서, 화살표 선택, 최근 목록, 미리 보기 윤곽이 놓일
//  frame, 팔레트 단축키와 명령 단축키의 겹침. 패널·AX 읽기·실행은 `CommandPaletteController`가 이 결과로 한다.
//
//  순수 로직 파일 — AppKit/AX를 import하지 않는다(Carbon은 키·수정자 상수만). scripts/harness-sources.sh에 있다.
//

import Carbon.HIToolbox
import CoreGraphics

nonisolated enum CommandPaletteSearch {
    /// 별칭 하나: 이 낱말들 중 하나의 앞부분과 맞으면 `matches`인 명령에 걸린다(대화에서 승인한 표, 2026-10-24).
    private struct Alias {
        let terms: [String]
        let matches: (WindowCommand) -> Bool
    }

    private static let aliases: [Alias] = [
        Alias(terms: ["max", "full", "fill", "zoom"]) { $0 == .maximize || $0 == .maximizeGaps },
        Alias(terms: ["gap", "gaps", "margin", "padding"]) { $0 == .maximizeGaps },
        Alias(terms: ["half", "halves", "1/2"]) { $0.displayName.hasSuffix("1/2") },
        Alias(terms: ["third", "thirds", "1/3"]) { $0.displayName.hasSuffix("1/3") },
        Alias(terms: ["two-thirds", "2/3"]) { $0.displayName.hasSuffix("2/3") },
        Alias(terms: ["shrink", "smaller", "resize"]) { $0.group == .relative },
        Alias(terms: ["display", "screen", "monitor"]) { $0.group == .display },
        Alias(terms: ["nudge", "move"]) { $0.displayName.hasPrefix("Move") },
        Alias(terms: ["center", "centre"]) { $0.displayName.contains("Center") },
        Alias(terms: ["top", "up"]) { words(of: $0.displayName).contains { $0 == "top" || $0 == "up" } },
        Alias(terms: ["bottom", "down"]) { words(of: $0.displayName).contains { $0 == "bottom" || $0 == "down" } },
        Alias(terms: ["undo", "back", "restore", "revert"]) { $0 == .undo }
    ]

    /// 검색어에 걸린 명령, 보일 순서대로. 순위: 이름이 검색어로 시작 → 이름의 낱말로 모두 걸림 → 별칭·그룹 이름으로 걸림.
    /// 같은 순위에서는 `recent`(최근이 앞)에 있는 것이 먼저, 그다음 메뉴 순서. 빈 검색어는 모두 같은 순위라 최근 + 메뉴 순서.
    static func results(
        query: String, recent: [String], commands: [WindowCommand] = WindowCommand.menuCommands
    ) -> [WindowCommand] {
        let needle = normalized(query)
        let tokens = words(of: needle)
        // 정렬 열쇠 하나에 순위 > 최근 > 메뉴 순서를 담는다(최근 자리 × 명령 수 + 메뉴 자리 < 명령 수²).
        let size = commands.count
        let keyed = commands.enumerated().compactMap { index, command -> (key: Int, command: WindowCommand)? in
            guard let rank = rank(command, needle: needle, tokens: tokens) else { return nil }
            let recentIndex = recent.firstIndex(of: command.identifier) ?? recent.count
            return ((rank * (recent.count + 1) + recentIndex) * size + index, command)
        }
        return keyed.sorted { $0.key < $1.key }.map(\.command)
    }

    /// 이것을 실패시키는 것: 순위 0(이름 시작) 조건을 빼는 것. 최근에 Shrink Left 1/2를 썼으면 "left"에서 그것이
    /// Left 1/2보다 앞에 온다(최근이 없으면 메뉴 순서가 가려 준다).
    private static func rank(_ command: WindowCommand, needle: String, tokens: [String]) -> Int? {
        let name = command.displayName.lowercased()
        if needle.isEmpty || name.hasPrefix(needle) { return 0 }
        let nameWords = words(of: name)
        if tokens.allSatisfy({ token in nameWords.contains { $0.hasPrefix(token) } }) { return 1 }
        // 핵심 그룹의 이름("Maximize · Undo · Center")은 분류가 아니라 명령 나열이라 넣지 않는다 — 넣으면 "max"에 Undo가 걸린다.
        let groupWords = command.group == .core ? [] : words(of: command.group.displayName.lowercased())
        let aliasTerms = aliases.filter { $0.matches(command) }.flatMap(\.terms)
        let all = nameWords + groupWords + aliasTerms
        if tokens.allSatisfy({ token in all.contains { $0.hasPrefix(token) } }) { return 2 }
        return nil
    }

    /// 소문자, 앞뒤 공백 제거, "two thirds"를 별칭 낱말 "two-thirds"로.
    private static func normalized(_ query: String) -> String {
        query.lowercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(
            of: "two thirds",
            with: "two-thirds"
        )
    }

    /// 공백과 그룹 이름의 가운뎃점으로 나눈 낱말.
    private static func words(of text: String) -> [String] {
        text.lowercased().split { $0 == " " || $0 == "·" }.map(String.init)
    }
}

/// 결과 목록에서 고른 줄. 끝에서 더 가지 않는다(감싸 돌지 않음).
nonisolated enum CommandPaletteSelection {
    static func moved(_ index: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index + delta, 0), count - 1)
    }
}

/// 팔레트로 실행한 명령의 최근 목록(식별자, 최근이 앞). 단축키·팝오버 실행은 넣지 않는다(사용자 결정 2026-10-24).
nonisolated enum CommandPaletteRecents {
    static let capacity = 5

    static func touched(_ identifier: String, in list: [String]) -> [String] {
        Array(([identifier] + list.filter { $0 != identifier }).prefix(capacity))
    }
}

/// 팔레트를 열 때 한 번 읽은 대상 창의 값(AX 좌표). 화살표를 누를 때마다 AX를 다시 부르지 않으려고 묶어 둔다 —
/// 응답 없는 앱이면 읽기 한 번이 해석 상한만큼 걸린다.
nonisolated struct CommandPalettePreviewContext: Equatable {
    let current: CGRect
    let workArea: CGRect
    let recorded: SnapRecord?
    /// 방향별 인접 디스플레이의 작업영역. 그 방향에 화면이 없으면 키가 없다.
    let adjacent: [SnapEdge: CGRect]
    /// 크기를 바꿀 수 있는지. 크기 고정 창(#167)이면 실행처럼 위치만 옮긴 frame을 보인다.
    let sizeSettable: SettableAnswer
}

nonisolated enum CommandPalettePreview {
    /// 고른 명령이 창을 놓을 frame. Undo(창 이력에 달림)와 디스플레이 이동(다른 화면)은 nil — 윤곽 없음(디자인 확정).
    /// 실행과 같은 `CommandPlanPolicy`·`FixedSizePlacementPolicy`를 거친다.
    static func target(for command: WindowCommand, in context: CommandPalettePreviewContext) -> CGRect? {
        switch command {
        case .undo, .moveToDisplay:
            return nil
        case .maximize, .maximizeGaps, .absolute, .snapThrow, .move, .relativeHalf, .relativeTwoThird:
            break
        }
        let plan = CommandPlanPolicy.decide(CommandPlanInput(
            command: command,
            current: context.current,
            workArea: context.workArea,
            recorded: context.recorded,
            adjacentWorkArea: command.adjacentEdge.flatMap { context.adjacent[$0] }
        ))
        let decision = FixedSizePlacementPolicy.decide(
            anchor: command.frameAnchor,
            current: context.current,
            requested: plan.target,
            workArea: area(containing: plan.target, in: context),
            sizeSettable: context.sizeSettable
        )
        switch decision {
        case .proceed:
            return plan.target
        case let .retarget(fixed):
            return fixed
        case .fail:
            return nil
        }
    }

    /// 목표가 놓일 화면의 작업영역. 실행은 목표 화면의 작업영역으로 모서리를 맞추므로(던지기면 옆 화면) 같게 고른다.
    private static func area(containing target: CGRect, in context: CommandPalettePreviewContext) -> CGRect {
        let center = CGPoint(x: target.midX, y: target.midY)
        return context.adjacent.values.first { $0.contains(center) } ?? context.workArea
    }
}

/// 팔레트를 여는 단축키. 명령이 아니어서 `HotkeyBinding`에 들어가지 않고 따로 저장·등록한다.
nonisolated enum CommandPaletteShortcut {
    /// 설정 녹화와 등록 실패 표시에 쓰는 식별자. 명령 식별자와 겹치지 않는다(`testCommandPaletteShortcut`).
    static let identifier = "commandPalette"
    /// ⌃⌥P. ⌃⌥Space는 macOS 입력 소스 전환과 겹쳐 기각(.docs 결정 기록).
    static let standard = HotkeyShortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey | optionKey))

    /// 팔레트와 같은 조합을 쓰는 명령의 식별자. 비어 있지 않으면 팔레트와 그 명령 모두 Duplicate다.
    static func conflicts(_ shortcut: HotkeyShortcut, in bindings: [HotkeyBinding]) -> Set<String> {
        Set(bindings.filter { $0.shortcut == shortcut }.map(\.command.identifier))
    }
}
