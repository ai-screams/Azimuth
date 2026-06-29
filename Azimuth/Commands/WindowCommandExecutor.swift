import Cocoa

@MainActor
enum WindowCommandExecutor {
    static func run(
        _ command: WindowCommand,
        on app: NSRunningApplication,
        undoStore: WindowUndoStore
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
            // undo는 직전 실제 frame 복원이라 anchor 보정 불필요(workArea: nil).
            let result = WindowFrameWriter.apply(previous, to: resolved, workArea: nil)
            if case .success = result {
                // 1단계 복원이므로 소비한 entry는 제거(반복 undo 방지 + 누적 방지).
                undoStore.clear(for: resolved.element, pid: resolved.pid)
            }
            return result
        }

        guard let workArea = WorkAreaResolver.workArea(forAXWindowFrame: resolved.frame.rect) else {
            return .failure(.workAreaUnavailable)
        }

        let preMoveFrame = resolved.frame.rect
        let target = targetFrame(for: command, current: preMoveFrame, workArea: workArea)
        // anchor 보정은 "target이 놓일 화면"의 작업영역 기준이어야 한다(디스플레이 간 throw 시 목적지 화면).
        // 같은 화면 명령이면 결과적으로 source와 동일. 못 구하면 source로 폴백.
        let anchorArea = WorkAreaResolver.workArea(forAXWindowFrame: target) ?? workArea
        let result = WindowFrameWriter.apply(target, to: resolved, workArea: anchorArea)
        // 되돌리기용 직전 frame은 적용에 "성공했을 때만" 저장한다. 실패/transient면 창이 움직이지
        // 않았으므로, 기록하면 직전 성공 명령의 undo 이력을 무의미한 현재 frame으로 덮어쓰게 된다.
        if case .success = result {
            undoStore.record(preMoveFrame, pid: resolved.pid, for: resolved.element)
        }
        return result
    }

    /// snapThrow·moveToDisplay만 인접 디스플레이를 알아야 하므로 여기서 분기하고, 나머지는 순수 FrameCalculator에 위임.
    private static func targetFrame(for command: WindowCommand, current: CGRect, workArea: CGRect) -> CGRect {
        switch command {
        case let .snapThrow(edge):
            return snapThrowTarget(edge, current: current, workArea: workArea)
        case let .moveToDisplay(edge):
            return moveToDisplayTarget(edge, current: current, workArea: workArea)
        case .maximize, .absolute, .move, .relativeHalf, .relativeTwoThird, .undo:
            return FrameCalculator.targetFrame(for: command, current: current, workArea: workArea)
        }
    }

    /// 이미 그 방향 절반을 채우고 있으면 인접 디스플레이의 반대쪽 절반으로 던지고, 아니면 현재 화면의 그 절반으로 스냅.
    private static func snapThrowTarget(_ edge: SnapEdge, current: CGRect, workArea: CGRect) -> CGRect {
        guard FrameCalculator.isSnapped(current, to: edge, workArea: workArea) else {
            return FrameCalculator.halfRect(edge, workArea: workArea)
        }
        let adjacent = DisplayResolver.adjacentWorkArea(forAXWindowFrame: current, edge: edge)
        return adjacent.map { FrameCalculator.halfRect(edge.opposite, workArea: $0) }
            ?? FrameCalculator.halfRect(edge, workArea: workArea)
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
        undoStore: WindowUndoStore
    ) -> Result<CGRect, WindowCommandError> {
        guard let app = tracker.targetApplication else {
            return .failure(.resolution(.noFrontmostApplication))
        }
        return run(command, on: app, undoStore: undoStore)
    }
}
