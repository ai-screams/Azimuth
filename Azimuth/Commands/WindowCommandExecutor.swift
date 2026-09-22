import Cocoa
import os

@MainActor
enum WindowCommandExecutor {
    // 해석 예산은 상수가 아니라 `AXMessagingTimeout.resolveBudget(for:)`이 사용자의 해석 상한에서
    // 계산한다. 개별 읽기는 상한으로 묶이지만 합은 묶이지 않기 때문이고, 상한을 고급 설정에서 바꿀 수
    // 있으므로 예산도 같이 움직여야 한다. 고정 3초이던 시절에는 Patient(1.0초)를 고른 사용자가 해석에
    // 성공하고도 예산에 걸려 조용히 버려졌다 — "느린 앱을 기다리겠다"는 선택이 침묵 실패를 늘렸다.
    //
    // 완전 비블로킹을 "백그라운드 AX 워커"로 풀려던 계획은 전제가 확인되지 않아 재범위화했다 —
    // AX 함수의 스레딩은 SDK 헤더에 문서화돼 있지 않고, 동종 윈도우 매니저는 메인스레드를 유지한 채
    // 타임아웃을 바운드한다. 자세한 근거는 `.docs/review/ax-main-thread-blocking-audit-2026-09-09.md`.

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
        // 해석은 **성공했는데** 느려서 중단하는 경우라 `.transient`(조용한 스킵)로 보내지 않는다 —
        // 다시 눌러도 똑같이 재현되므로, 침묵은 사용자에게 "단축키가 고장 났다"고 가르친다.
        let budget = AXMessagingTimeout.resolveBudget(for: FocusedWindowResolver.resolveTimeout)
        if ProcessInfo.processInfo.systemUptime - startedAt > budget {
            return .failure(.resolveBudgetExceeded)
        }

        if command == .undo {
            guard let previous = undoStore.previousFrame(for: resolved.element, pid: resolved.pid) else {
                return .failure(.noUndoState)
            }
            // undo는 직전 실제 frame 복원이라 anchor 보정 불필요(workArea: nil, anchor: topLeft).
            let outcome = WindowFrameWriter.apply(FrameWriteRequest(
                target: previous,
                resolved: resolved,
                workArea: nil,
                anchor: WindowCommand.undo.frameAnchor,
                startedAt: startedAt
            ))
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
        // 목표 frame 결정(snapThrow 상태기계·moveToDisplay 목적지)은 순수 계층에 위임한다 — 인접 작업영역과
        // 스냅 기록은 둘 다 값이라, 창을 옆 모니터로 던지는 동작을 AX 없이 전수 테스트할 수 있다.
        // 여기서는 그 두 값을 읽어 넘기기만 한다.
        let adjacent = command.adjacentEdge.flatMap {
            DisplayResolver.adjacentWorkArea(forAXWindowFrame: preMoveFrame, edge: $0)
        }
        let plan = CommandPlanPolicy.decide(CommandPlanInput(
            command: command,
            current: preMoveFrame,
            workArea: workArea,
            recorded: snapStore.state(for: resolved.element, pid: resolved.pid),
            adjacentWorkArea: adjacent
        ))
        // anchor 보정은 "target이 놓일 화면"의 작업영역 기준이어야 한다(디스플레이 간 throw 시 목적지 화면).
        // 같은 화면 명령이면 결과적으로 source와 동일. 못 구하면 source로 폴백.
        let anchorArea = WorkAreaResolver.workArea(forAXWindowFrame: plan.target) ?? workArea
        // 고정 모서리 의도는 명령이 안다 — 상대 축소는 명시적 모서리, 나머지는 작업영역 모서리 추론(M-4).
        let outcome = WindowFrameWriter.apply(FrameWriteRequest(
            target: plan.target,
            resolved: resolved,
            workArea: anchorArea,
            anchor: command.frameAnchor,
            startedAt: startedAt
        ))
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
