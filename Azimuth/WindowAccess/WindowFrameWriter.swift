import ApplicationServices
import Foundation
import os

/// frame 적용 결과. achieved(마지막으로 읽은 실제 frame)를 성공·실패 양쪽에서 실어, Executor가
/// "창이 실제로 변했는가"로 Undo를 판정하게 한다(부분 실패로 이동한 창의 복원 지점을 잃지 않고,
/// 무시된 쓰기로 직전 Undo를 덮지 않게). error가 nil이면 UI 성공, 있으면 실패/transient.
/// 읽기 자체가 실패하면 결과를 알 수 없으므로 achieved는 nil이다.
///
/// achieved가 nil일 때 상태 커밋의 유일한 근거가 `mayHaveMutated`다 — AX 쓰기가 하나라도 성공했다면
/// 창은 움직였을 수 있으므로 복원점을 남겨야 한다(감사 H-2). 판정 자체는 `CommandOutcomePolicy`가 한다.
nonisolated struct FrameApplyResult: Equatable {
    let achieved: CGRect?
    let error: WindowCommandError?
    /// position/size 쓰기 중 하나라도 AX success를 반환했는가.
    let mayHaveMutated: Bool
}

/// AX 쓰기는 메인 스레드에서만 안전하며 권한 캐시(@MainActor)와 애니메이션 억제 상태를 다루므로 @MainActor.
///
/// 쓰기 전략(메이저 윈도우 매니저 컨센서스):
///  - `AnimationSuppressor`로 대상 앱의 애니메이션 속성을 잠시 꺼서 AX 쓰기를 동기·비애니메이션화한다(깜빡임 제거).
///  - 작아질 때만 size→position 순서(줄인 뒤 이동 → 옛 큰 크기로 옆 모니터 침범 방지), 커질 땐 position→size.
///  - 제약 앱이 목표 크기에 못 미치면 실제 크기를 읽어 anchored origin을 "한 번만" 써서(KI-003 2단계 깜빡임 회피)
///    스냅 모서리를 유지한다.
///  - 성공/실패는 AX 쓰기 결과로 판정하고(제약 앱이 목표 미달이어도 쓰기 성공이면 성공), "실제로 변했는가"는
///    Executor가 achieved로 따로 판정한다(Undo 정합성 — 감사 H-1).
@MainActor
enum WindowFrameWriter {
    /// shrink 판정 데드밴드(반올림 오차로 같은 크기가 미세하게 작게 읽히는 것을 무시).
    private static let shrinkDeadband: CGFloat = 1
    /// anchored 보정을 걸지 판정하는 size 허용오차(순수 계층과 공유).
    private static let sizeTolerance = FrameApply.sizeTolerance
    /// 애니메이션 억제 상태(PID별)는 명령 간 유지되어야 하므로 writer가 단일 인스턴스로 소유한다.
    private static let suppressor = AnimationSuppressor()

    /// 요청이 target/창/작업영역/anchor 와 **명령 시작 시각**을 함께 운반한다(`FrameWriteRequest`).
    static func apply(_ request: FrameWriteRequest) -> FrameApplyResult {
        // 권한 가드를 쓰기 경계에도 둔다(방어적 — 호출 순서에 의존하지 않게).
        guard AccessibilityPermissionService.currentStatus().isTrusted else {
            return FrameApplyResult(achieved: nil, error: .resolution(.permissionDenied), mayHaveMutated: false)
        }
        let element = request.resolved.element
        let current = request.current
        let target = request.target
        // 여기서 한 번만 계산해 writeFrame 에 넘긴다 — 두 곳에서 따로 계산하면 한쪽만 고쳤을 때 조용히 갈라진다.
        let moves = FrameApply.movesOrigin(from: current, to: target)
        let resizes = FrameApply.resizesSize(from: current, to: target)
        // 실제로 바뀌는 축의 권한만 요구한다 — 이동만 하는 고정크기 창의 Move를 허용하고, 불필요한
        // size AX IPC와 부분 실패 면적을 줄인다(감사 M-3).
        if moves, !isSettable(element, kAXPositionAttribute) {
            return FrameApplyResult(achieved: nil, error: .notMovable, mayHaveMutated: false)
        }
        if resizes, !isSettable(element, kAXSizeAttribute) {
            return FrameApplyResult(achieved: nil, error: .notResizable, mayHaveMutated: false)
        }
        // 어느 축도 안 바뀌면 no-op — AX 쓰기 없이 현재 frame을 성공으로 반환(불필요한 쓰기·재정규화 방지).
        guard moves || resizes else {
            return FrameApplyResult(achieved: current, error: nil, mayHaveMutated: false)
        }

        // 상한 상향은 여기서부터다 — 위 isSettable 2회는 해석 단계의 짧은 상한 그대로 돌았다.
        // 상향의 근거는 "쓰기 타임아웃이 `.transient`(조용한 스킵)로 매핑된다"인데, 그 성질을 갖는
        // 것은 `applyError`가 읽는 position/size **set 뿐**이다. isSettable 실패는 `.notMovable`/
        // `.notResizable`로 사용자에게 보이므로 오히려 빨리 실패하는 편이 낫다 — 근거가 없는 곳까지
        // 상한을 넓히면 예산 검사 어디에도 안 걸리는 대기만 늘어난다.
        //
        // 억제 probe/쓰기는 대상 앱 element를 쓴다. 이쪽까지 짧게 잡으면 느린 Electron 앱에서 억제가
        // 걸리지 않아 KI-002 깜빡임이 나므로(억제가 필요한 바로 그 부류다) 넉넉한 상한을 준다.
        //
        // 상향 실패 시 중단하지 않는 것이 의도다: element는 해석 단계가 걸어둔 짧은 상한을 그대로
        // 유지하므로 기본 6초로 되돌아가는 일이 없다 — WindowAccess/AGENTS.md가 금지하는 것은 그
        // 6초 폴백이고, 0을 넘겨야 그렇게 된다. 짧은 상한으로 계속하는 편이 항상 더 안전하므로
        // 중단으로 "고치지" 말 것.
        raiseMessagingTimeout(on: request.resolved.appElement, label: "app")
        let didSuppress = suppressor.suppress(appElement: request.resolved.appElement, pid: request.resolved.pid)
        raiseMessagingTimeout(on: element, label: "window")
        let result = writeFrame(request, moves: moves, resizes: resizes)
        if didSuppress { suppressor.scheduleRestore(pid: request.resolved.pid) }
        return result
    }

    // MARK: - 프레임 쓰기

    /// 바뀌는 축만 쓴다(권한 가드와 `moves`/`resizes` 계산은 `apply` 가 끝냈다). 이동만이면 size를,
    /// 리사이즈만이면 position을 건드리지 않아 AX IPC와 부분 실패 면적을 줄인다(감사 M-3).
    ///
    /// **이 함수 안에서 시각을 읽지 않는다.** 재시도 예산의 기준점은 `request.startedAt`(명령 시작)이고,
    /// 여기서 따로 시계를 잡으면 그 앞구간(해석·억제)의 프리즈가 예산에서 빠진다.
    private static func writeFrame(
        _ request: FrameWriteRequest,
        moves: Bool,
        resizes: Bool
    ) -> FrameApplyResult {
        let element = request.resolved.element
        let current = request.current
        let target = request.target
        let shrinking = resizes
            && (target.width < current.width - shrinkDeadband || target.height < current.height - shrinkDeadband)
        // 쓰기가 하나라도 먹었는지 — 최종 read가 실패했을 때 복원점을 남길지의 유일한 근거다(감사 H-2).
        var mutated = false
        // (1) 작아질 때만 size-first: 줄인 뒤 이동해야 옛 큰 크기로 옆 모니터를 침범하지 않는다.
        if shrinking {
            let shrinkError = AXAttribute.set(element, kAXSizeAttribute as String, size: target.size)
            mutated = mutated || shrinkError == .success
        }

        // (2) 이동이 있으면: 제약 앱이 목표보다 큰 크기에 머물 때 실제 크기를 읽어 anchored origin을 1회 쓴다.
        var positionError = AXError.success
        if moves {
            let origin = anchoredOrigin(request)
            positionError = AXAttribute.set(element, kAXPositionAttribute as String, point: origin)
            mutated = mutated || positionError == .success
        }
        // (3) 리사이즈가 있으면 크기 재확정(모니터를 넘어가며 클램프됐을 수 있음). 이동만이면 size는 안 건드린다.
        var sizeError = AXError.success
        if resizes {
            sizeError = AXAttribute.set(element, kAXSizeAttribute as String, size: target.size)
            mutated = mutated || sizeError == .success
        }

        // (4) verify + 1회 재시도(비동기·부분수용 앱). reached는 origin 2pt·size 8pt 오차 허용(증분 앱 헛재시도 방지).
        // 재시도 origin은 다시 읽은 실제 크기로 anchor 재계산(첫 추정이 어긋났을 때 보정).
        // 재시도 결과를 최종 판정에 반영한다 — 재시도 중에만 생긴 일시적 실패를 success로 오분류하지 않게.
        //
        // 재시도 여부는 순수 정책이 정한다 — 읽기 실패·도달·예산 초과의 조합을 AX 없이 전수 검증하기 위해서다.
        // 경과는 **명령 시작부터**다(`request.startedAt`): 해석·억제가 이미 쓴 시간이 들어가야, 느린 앱에서
        // 추가 쓰기로 프리즈를 늘리지 않는다는 가드가 실제로 작동한다(감사 H-3).
        let achievedFrame = readFrame(element)
        var achieved = achievedFrame
        let retry = WriteRetryPolicy.decide(WriteRetryInput(
            elapsed: ProcessInfo.processInfo.systemUptime - request.startedAt,
            budget: AXMessagingTimeout.writeRetryBudget(for: FocusedWindowResolver.resolveTimeout),
            reachedTarget: achievedFrame.map { FrameApply.reached(target: target, achieved: $0) },
            moves: moves,
            resizes: resizes
        ))
        if retry.retryPosition {
            positionError = AXAttribute.set(element, kAXPositionAttribute as String, point: anchoredOrigin(request))
            mutated = mutated || positionError == .success
        }
        if retry.retrySize {
            sizeError = AXAttribute.set(element, kAXSizeAttribute as String, size: target.size)
            mutated = mutated || sizeError == .success
        }
        let retried = retry.shouldRetry
        // 재시도로 창이 또 움직였거나 검증 읽기 자체가 실패했을 때만 최종 frame을 다시 읽는다.
        // 이미 목표에 도달한 정상 경로에서는 검증 frame이 곧 최종 frame이다 — 명령마다 position/size
        // 읽기 2회가 줄어든다(감사 H-1). 재시도를 건너뛴 느린 앱에서도 한 번 더 읽지 않는다.
        if retried || achieved == nil { achieved = readFrame(element) }

        // 읽기 실패면 결과를 알 수 없어 achieved=nil(Executor가 mayHaveMutated로 복원점을 판단한다).
        guard let achieved else {
            return FrameApplyResult(achieved: nil, error: .applyFailed, mayHaveMutated: mutated)
        }
        return FrameApplyResult(
            achieved: achieved,
            error: applyError(position: positionError, size: sizeError),
            mayHaveMutated: mutated
        )
    }

    /// 쓰기 결과 → UI 오류. 둘 다 성공이면 nil(제약 앱이 목표 미달이어도 성공). Space 전환·애니메이션 중
    /// cannotComplete는 transient(조용히 스킵), 그 외 실패는 applyFailed.
    private static func applyError(position: AXError, size: AXError) -> WindowCommandError? {
        if position == .success, size == .success { return nil }
        if position == .cannotComplete || size == .cannotComplete { return .transient }
        return .applyFailed
    }

    /// 실제 크기를 읽어 anchor 의도대로 고정 모서리를 유지하는 origin.
    ///  - topLeft: 목표 origin 그대로(좌/상 고정 — AX 읽기 불필요).
    ///  - right/bottom: 상대 축소. 앱이 요청보다 작게/크게 반올림해도 그 모서리를 고정하려면 항상 실제
    ///    크기를 읽어 다시 계산한다(감사 M-4 — 반복 축소의 셀 단위 드리프트 방지).
    ///  - workAreaEdges: 제약 앱이 목표보다 "클 때"만 스냅 모서리를 유지(기존 동작).
    private static func anchoredOrigin(_ request: FrameWriteRequest) -> CGPoint {
        let element = request.resolved.element
        let target = request.target
        let workArea = request.workArea
        switch request.anchor {
        case .topLeft:
            return target.origin
        case .right, .bottom:
            guard let actual = AXAttribute.size(element, kAXSizeAttribute as String) else { return target.origin }
            return FrameCalculator.anchoredOrigin(
                anchor: request.anchor, actualSize: actual, target: target, workArea: workArea ?? target
            )
        case .workAreaEdges:
            guard let workArea,
                  let actual = AXAttribute.size(element, kAXSizeAttribute as String),
                  FrameCalculator.isConstrained(actualSize: actual, target: target.size, tolerance: sizeTolerance)
            else { return target.origin }
            return FrameCalculator.anchoredOrigin(
                anchor: .workAreaEdges, actualSize: actual, target: target, workArea: workArea
            )
        }
    }

    // MARK: - AX 래퍼

    /// 읽은 frame이 비정상(NaN·무한·0·음수)이면 nil로 취급한다. NaN은 모든 비교가 false라
    /// `FrameApply.changed`에서 "변함"으로 나와 **허위 undo 항목**을 남기므로(멀쩡한 직전 항목을 덮음)
    /// 판정에 흘러들기 전에 여기서 걸러야 한다.
    private static func readFrame(_ element: AXUIElement) -> CGRect? {
        guard let origin = AXAttribute.point(element, kAXPositionAttribute as String),
              let size = AXAttribute.size(element, kAXSizeAttribute as String)
        else { return nil }
        let frame = CGRect(origin: origin, size: size)
        return FrameCalculator.isUsableFrame(frame) ? frame : nil
    }

    /// 쓰기 단계용 messaging timeout 상향. 실패는 로그만 남기고 진행한다(위 apply의 주석 참고).
    private static func raiseMessagingTimeout(on element: AXUIElement, label: String) {
        let error = AXUIElementSetMessagingTimeout(element, AXMessagingTimeout.write)
        guard error != .success else { return }
        Log.windows.error(
            "SetMessagingTimeout(write/\(label)) failed (\(error.rawValue)) — keeping the shorter resolve timeout"
        )
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return error == .success && settable.boolValue
    }
}
