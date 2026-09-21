import Cocoa

@MainActor
enum WindowCommandExecutor {
    /// 응답 지연 앱에서 명령 해석(다수의 AX 읽기)이 이 상한을 넘으면, 쓰기 단계의 추가 AX 호출로
    /// MainActor 프리즈를 키우지 않고 조용히 중단한다(감사 H-3 부분 완화 — AX 호출은 동기라 개별
    /// 호출은 못 끊으므로 호출 경계에서만 검사한다).
    ///
    /// 이 값은 해석 타임아웃이 2초였을 때 정해졌고 그때는 최악 해석 시간(6~8회 × 2초)보다 훨씬
    /// 아래였다. `FocusedWindowResolver.resolveTimeout`을 0.5초로 낮춘 뒤로는 최악 해석 시간이
    /// 3~4초라 이 예산이 거의 그 경계에 놓인다 — 즉 지금은 "해석이 끝난 뒤의 사후 안전망"에 가깝고,
    /// 실효 상한은 타임아웃 쪽이다. 값은 그대로 두되 그 역할이 바뀐 것을 기록해 둔다.
    ///
    /// 완전 비블로킹을 "백그라운드 AX 워커"로 풀려던 계획은 전제가 확인되지 않아 재범위화했다 —
    /// AX 함수의 스레딩은 SDK 헤더에 문서화돼 있지 않고, 동종 윈도우 매니저는 메인스레드를 유지한 채
    /// 타임아웃을 바운드한다. 자세한 근거는 `.docs/review/ax-main-thread-blocking-audit-2026-09-09.md`.
    private static let resolveBudgetSeconds: CFTimeInterval = 3

    /// 명령 1회. 권한 거부로 실패하면 **캐시가 낡았을 뿐인지** 한 번 확인하고 재실행한다.
    ///
    /// `AccessibilityPermissionService`의 캐시는 명령마다 동기 tccd 호출이 나가는 것을 막아 주지만
    /// 무효화 지점이 앱 활성화·메뉴 열기 둘뿐이다. 사용자가 Azimuth를 활성화하지 않은 채 System
    /// Settings에서 권한을 켜고 돌아와 단축키를 누르면, 캐시는 `false`로 남아 읽기 가드가 AX를 부르기도
    /// 전에 `.permissionDenied`를 돌려준다 — 권한은 이미 있는데 명령이 실패한다.
    ///
    /// 재시도는 안전하다: `.permissionDenied` 생성 지점 셋이 모두 **창을 건드리기 전**이라
    /// (`WindowFrameWriter`의 쓰기 경계 가드는 `mayHaveMutated: false`) 부분 적용 상태가 없다.
    /// 권한이 정말 없으면 갱신된 조회가 false라 재실행조차 하지 않는다.
    ///
    /// 재시도가 **느린 앱의 프리즈를 두 배로 만들지 않는다.** 해석 예산 타이머는 시도마다 새로 시작하지만,
    /// 응답 없는 앱이 내는 `.cannotComplete`는 `.appUnresponsive`로 매핑되지 `.permissionDenied`가 되지 않는다.
    /// 즉 재시도 조건은 느림이 아니라 **OS 수준의 권한 거부**이고, 그건 대기 없이 즉시 반환된다.
    ///
    /// 여기(`run` 안)에 두는 이유: DEBUG 상태바 메뉴도 이 함수를 직접 호출한다. 호출자 쪽에 두면
    /// 같은 primitive의 두 경로가 낡은 캐시에서 다르게 동작한다. 권한 안내(창 띄우기)는 UX라 앱이 맡는다.
    static func run(
        _ command: WindowCommand,
        on app: NSRunningApplication,
        undoStore: WindowUndoStore,
        snapStore: SnapStateStore
    ) -> Result<CGRect, WindowCommandError> {
        let first = attempt(command, on: app, undoStore: undoStore, snapStore: snapStore)
        guard case .failure(.resolution(.permissionDenied)) = first else { return first }
        AccessibilityPermissionService.invalidateCache()
        guard AccessibilityPermissionService.currentStatus().isTrusted else { return first }
        let retried = attempt(command, on: app, undoStore: undoStore, snapStore: snapStore)
        if case .success = retried {
            // 사용자에게는 보이지 않는 자가 치유다. 기록이 없으면 "권한을 켠 직후 첫 단축키가 가끔
            // 실패하던" 현상이 얼마나 흔한지 나중에 알 길이 없다.
            Log.app.debug("Permission cache was stale; \(command.displayName, privacy: .public) succeeded on retry.")
        }
        return retried
    }

    private static func attempt(
        _ command: WindowCommand,
        on app: NSRunningApplication,
        undoStore: WindowUndoStore,
        snapStore: SnapStateStore
    ) -> Result<CGRect, WindowCommandError> {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let resolved: ResolvedWindow
        switch FocusedWindowResolver.resolveFocusedWindow(for: app) {
        case let .success(window):
            resolved = window
        case let .failure(error):
            return .failure(.resolution(error))
        }
        // 응답 지연 앱: 해석이 예산을 넘겼으면 쓰기 단계의 추가 AX 호출로 프리즈를 키우지 않는다(H-3).
        if ProcessInfo.processInfo.systemUptime - startedAt > resolveBudgetSeconds {
            return .failure(.transient)
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
        // Undo·Snap 커밋 판단은 순수 계층에 위임한다 — 부분 적용·최종 read 실패 같은 조합을 AX 없이
        // 전수 테스트할 수 있게 하기 위해서다(감사 H-2/H-3). 여기서는 결정을 적용만 한다.
        let decision = CommandOutcomePolicy.decide(CommandOutcome(
            pre: preMoveFrame,
            target: plan.target,
            achieved: outcome.achieved,
            failed: outcome.error != nil,
            mayHaveMutated: outcome.mayHaveMutated,
            snappedEdge: plan.snappedEdge
        ))
        commit(decision, pre: preMoveFrame, resolved: resolved, undoStore: undoStore, snapStore: snapStore)
        return result(from: outcome, fallback: plan.target)
    }

    /// 결정을 상태 저장소에 적용한다. 판단은 `CommandOutcomePolicy`가 이미 끝냈고 여기서는 실행만 한다.
    private static func commit(
        _ decision: OutcomeDecision,
        pre: CGRect,
        resolved: ResolvedWindow,
        undoStore: WindowUndoStore,
        snapStore: SnapStateStore
    ) {
        if decision.recordUndo {
            undoStore.record(pre, pid: resolved.pid, for: resolved.element)
        }
        switch decision.snap {
        case .keep:
            break
        case let .record(edge, frame):
            // snapThrow는 이 명령 뒤 창이 스냅된 edge를 실제 frame으로 기록한다(다음 입력의 던지기 판정용).
            // 기하만으로는 제약 앱을 인식하지 못하므로 상태로 보완한다.
            snapStore.record(edge: edge, frame: frame, pid: resolved.pid, for: resolved.element)
        case .clear:
            snapStore.clear(for: resolved.element, pid: resolved.pid)
        }
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
