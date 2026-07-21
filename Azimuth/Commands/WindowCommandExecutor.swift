import Cocoa

@MainActor
enum WindowCommandExecutor {
    static func run(
        _ command: WindowCommand,
        on app: NSRunningApplication,
        undoStore: WindowUndoStore,
        snapStore: SnapStateStore
    ) -> Result<CGRect, WindowCommandError> {
        let resolved: ResolvedWindow
        switch FocusedWindowResolver.resolveFocusedWindow(for: app) {
        case let .success(window):
            resolved = window
        case let .failure(error):
            return .failure(.resolution(error))
        }

        if command == .undo {
            guard let previous = undoStore.previousFrame(for: resolved.element, pid: resolved.pid) else {
                return .failure(.noUndoState)
            }
            // undo는 직전 실제 frame 복원이라 anchor 보정 불필요(workArea: nil, anchor: topLeft).
            let outcome = WindowFrameWriter.apply(
                previous, to: resolved, workArea: nil, anchor: WindowCommand.undo.frameAnchor
            )
            // 복원이 실제로 직전 frame에 도달했을 때만 소비한 entry를 제거한다(부분 복원·미도달이면
            // 재시도 여지를 남긴다 — 명목상 성공이 아니라 achieved 기준. 감사 H-1).
            if let achieved = outcome.achieved, FrameApply.reached(target: previous, achieved: achieved) {
                undoStore.clear(for: resolved.element, pid: resolved.pid)
            }
            return result(from: outcome, fallback: previous)
        }

        guard let workArea = WorkAreaResolver.workArea(forAXWindowFrame: resolved.frame.rect) else {
            return .failure(.workAreaUnavailable)
        }

        let preMoveFrame = resolved.frame.rect
        let plan = targetPlan(
            for: command, current: preMoveFrame, workArea: workArea, resolved: resolved, snapStore: snapStore
        )
        // anchor 보정은 "target이 놓일 화면"의 작업영역 기준이어야 한다(디스플레이 간 throw 시 목적지 화면).
        // 같은 화면 명령이면 결과적으로 source와 동일. 못 구하면 source로 폴백.
        let anchorArea = WorkAreaResolver.workArea(forAXWindowFrame: plan.target) ?? workArea
        // 고정 모서리 의도는 명령이 안다 — 상대 축소는 명시적 모서리, 나머지는 작업영역 모서리 추론(M-4).
        let outcome = WindowFrameWriter.apply(
            plan.target, to: resolved, workArea: anchorArea, anchor: command.frameAnchor
        )
        if let achieved = outcome.achieved {
            // 되돌리기용 직전 frame은 창이 "실제로" 변했을 때만 저장한다(achieved 기준 — 감사 H-1):
            //  - 부분 실패라도 창이 이동했으면 기록(복원 지점 보존).
            //  - 무시된 쓰기·no-op(예: 인접 디스플레이 없는 snapThrow/moveToDisplay)이면 미기록 → 직전
            //    성공 명령의 undo를 무의미한 frame으로 덮지 않는다.
            if FrameApply.changed(pre: preMoveFrame, achieved: achieved) {
                undoStore.record(preMoveFrame, pid: resolved.pid, for: resolved.element)
            }
            // snapThrow는 이 명령 뒤 창이 스냅된 edge를 실제 frame으로 기록한다(다음 입력의 던지기 판정용).
            // 기하만으로는 제약 앱을 인식하지 못하므로 상태로 보완한다(감사 H-2).
            if let snappedEdge = plan.snappedEdge {
                snapStore.record(edge: snappedEdge, frame: achieved, pid: resolved.pid, for: resolved.element)
            }
        }
        return result(from: outcome, fallback: plan.target)
    }

    /// FrameApplyResult → 공개 Result. error가 있으면 실패, 없으면 성공(achieved, 없으면 fallback).
    private static func result(
        from outcome: FrameApplyResult,
        fallback: CGRect
    ) -> Result<CGRect, WindowCommandError> {
        if let error = outcome.error {
            return .failure(error)
        }
        return .success(outcome.achieved ?? fallback)
    }

    /// 명령의 목표 frame과, snapThrow인 경우 이 명령 뒤 창이 스냅될 edge(기록용)를 함께 정한다.
    /// snapThrow·moveToDisplay만 인접 디스플레이·스냅 상태를 알아야 하므로 여기서 분기하고, 나머지는
    /// 순수 FrameCalculator에 위임한다.
    private static func targetPlan(
        for command: WindowCommand,
        current: CGRect,
        workArea: CGRect,
        resolved: ResolvedWindow,
        snapStore: SnapStateStore
    ) -> (target: CGRect, snappedEdge: SnapEdge?) {
        switch command {
        case let .snapThrow(edge):
            let recorded = snapStore.state(for: resolved.element, pid: resolved.pid)
            return snapThrowPlan(edge, current: current, workArea: workArea, recorded: recorded)
        case let .moveToDisplay(edge):
            return (moveToDisplayTarget(edge, current: current, workArea: workArea), nil)
        case .maximize, .maximizeGaps, .absolute, .move, .relativeHalf, .relativeTwoThird, .undo:
            return (FrameCalculator.targetFrame(for: command, current: current, workArea: workArea), nil)
        }
    }

    /// 이미 그 방향에 스냅돼 있으면(엄격 기하 또는 Azimuth가 스냅한 기록) 인접 디스플레이의 반대쪽 절반으로
    /// 던지고, 아니면 현재 화면의 그 절반으로 스냅한다. 인접 디스플레이가 없으면 현 위치를 그대로 유지한다
    /// (재스냅으로 미세하게 밀지 않음 — README "No adjacent display → stays put". 감사 M-1).
    /// 반환하는 edge는 이 명령 뒤 창이 스냅되는 방향(스냅/유지=진입 edge, 던지기=반대쪽 edge).
    private static func snapThrowPlan(
        _ edge: SnapEdge,
        current: CGRect,
        workArea: CGRect,
        recorded: SnapRecord?
    ) -> (target: CGRect, snappedEdge: SnapEdge?) {
        guard FrameCalculator.isAlreadySnapped(current: current, edge: edge, workArea: workArea, recorded: recorded)
        else {
            return (FrameCalculator.halfRect(edge, workArea: workArea), edge)
        }
        guard let adjacent = DisplayResolver.adjacentWorkArea(forAXWindowFrame: current, edge: edge) else {
            return (current, edge)
        }
        return (FrameCalculator.halfRect(edge.opposite, workArea: adjacent), edge.opposite)
    }

    /// 모양과 무관하게 그 방향 인접 디스플레이로 상대 위치·크기를 유지해 이동. 인접 없으면 현 위치 유지.
    private static func moveToDisplayTarget(_ edge: SnapEdge, current: CGRect, workArea: CGRect) -> CGRect {
        guard let destination = DisplayResolver.adjacentWorkArea(forAXWindowFrame: current, edge: edge) else {
            return current
        }
        return FrameCalculator.displayMoveRect(current, from: workArea, to: destination)
    }

    static func run(
        _ command: WindowCommand,
        tracker: FrontmostAppTracker,
        undoStore: WindowUndoStore,
        snapStore: SnapStateStore
    ) -> Result<CGRect, WindowCommandError> {
        guard let app = tracker.targetApplication else {
            return .failure(.resolution(.noFrontmostApplication))
        }
        return run(command, on: app, undoStore: undoStore, snapStore: snapStore)
    }
}
