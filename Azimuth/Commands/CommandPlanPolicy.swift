//
//  CommandPlanPolicy.swift
//  Azimuth
//
//  "이 명령이 창을 어디에 놓을 것인가"만 담당하는 순수 결정 계층. snapThrow의 상태기계(안 스냅 → 스냅,
//  이미 스냅 → 인접 디스플레이의 반대쪽 절반으로 던지기, 인접 없음 → 제자리)와 moveToDisplay의 목적지
//  선택이 여기 있다. Executor에서 분리한 이유는 CommandOutcomePolicy와 같다 — 인접 디스플레이 작업영역과
//  스냅 기록은 둘 다 값이라 넘길 수 있으므로, 창을 옆 모니터로 던지는 동작을 AX 없이 swiftc 하네스에서
//  전수 검증한다.
//
//  순수 로직 파일 — AppKit/AX를 import하지 않는다(계층 규율, Commands/AGENTS.md). CoreGraphics만 사용.
//  새 순수 파일은 scripts/harness-sources.sh 에 추가해야 하네스가 컴파일한다.
//

import CoreGraphics

/// 목표 frame을 정하는 데 필요한 값 전부. 파라미터로 흘리지 않고 묶는 이유는 `CommandOutcome`과 같다 —
/// 다섯 개면 이미 SwiftLint 상한이라 여유가 0이다.
nonisolated struct CommandPlanInput: Equatable {
    let command: WindowCommand
    /// 명령 직전에 읽은 창 frame(AX 좌표).
    let current: CGRect
    /// 창이 지금 있는 화면의 작업영역(AX 좌표).
    let workArea: CGRect
    /// Azimuth가 기록해 둔 이 창의 스냅 상태. 기하만으로는 제약 앱(정확한 반쪽에 못 미치는 창)을
    /// 알아보지 못해 상태로 보완한다.
    let recorded: SnapRecord?
    /// 이 명령의 방향(`WindowCommand.adjacentEdge`)에 있는 인접 디스플레이의 작업영역.
    /// 그 방향에 화면이 없거나 방향이 없는 명령이면 nil.
    let adjacentWorkArea: CGRect?
}

nonisolated struct CommandPlan: Equatable {
    let target: CGRect
    /// 이 명령이 성공하면 창이 스냅되는 edge. 스냅 계열이 아니면 nil.
    let snappedEdge: SnapEdge?
}

nonisolated enum CommandPlanPolicy {
    /// 명령의 목표 frame과, snapThrow인 경우 이 명령 뒤 창이 스냅될 edge(기록용)를 함께 정한다.
    /// snapThrow·moveToDisplay만 인접 디스플레이·스냅 상태를 알아야 하므로 여기서 분기하고, 나머지는
    /// 순수 FrameCalculator에 위임한다.
    static func decide(_ input: CommandPlanInput) -> CommandPlan {
        switch input.command {
        case let .snapThrow(edge):
            return snapThrowPlan(edge, input: input)
        case .moveToDisplay:
            return CommandPlan(target: moveToDisplayTarget(input), snappedEdge: nil)
        case .maximize, .maximizeGaps, .absolute, .move, .relativeHalf, .relativeTwoThird, .undo:
            let target = FrameCalculator.targetFrame(
                for: input.command, current: input.current, workArea: input.workArea
            )
            return CommandPlan(target: target, snappedEdge: nil)
        }
    }

    /// 이미 그 방향에 스냅돼 있으면(엄격 기하 또는 Azimuth가 스냅한 기록) 인접 디스플레이의 반대쪽 절반으로
    /// 던지고, 아니면 현재 화면의 그 절반으로 스냅한다. 인접 디스플레이가 없으면 현 위치를 그대로 유지한다
    /// (재스냅으로 미세하게 밀지 않음 — README "No adjacent display → stays put". 감사 M-1).
    /// 반환하는 edge는 이 명령 뒤 창이 스냅되는 방향(스냅/유지=진입 edge, 던지기=반대쪽 edge).
    private static func snapThrowPlan(_ edge: SnapEdge, input: CommandPlanInput) -> CommandPlan {
        let alreadySnapped = FrameCalculator.isAlreadySnapped(
            current: input.current, edge: edge, workArea: input.workArea, recorded: input.recorded
        )
        guard alreadySnapped else {
            return CommandPlan(target: FrameCalculator.halfRect(edge, workArea: input.workArea), snappedEdge: edge)
        }
        guard let adjacent = input.adjacentWorkArea else {
            return CommandPlan(target: input.current, snappedEdge: edge)
        }
        let thrown = FrameCalculator.halfRect(edge.opposite, workArea: adjacent)
        return CommandPlan(target: thrown, snappedEdge: edge.opposite)
    }

    /// 모양과 무관하게 그 방향 인접 디스플레이로 상대 위치·크기를 유지해 이동. 인접 없으면 현 위치 유지.
    private static func moveToDisplayTarget(_ input: CommandPlanInput) -> CGRect {
        guard let destination = input.adjacentWorkArea else { return input.current }
        return FrameCalculator.displayMoveRect(input.current, from: input.workArea, to: destination)
    }
}
