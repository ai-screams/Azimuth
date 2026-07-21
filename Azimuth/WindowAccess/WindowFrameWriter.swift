import ApplicationServices

/// frame 적용 결과. achieved(마지막으로 읽은 실제 frame)를 성공·실패 양쪽에서 실어, Executor가
/// "창이 실제로 변했는가"로 Undo를 판정하게 한다(부분 실패로 이동한 창의 복원 지점을 잃지 않고,
/// 무시된 쓰기로 직전 Undo를 덮지 않게). error가 nil이면 UI 성공, 있으면 실패/transient.
/// 읽기 자체가 실패하면 결과를 알 수 없으므로 achieved는 nil이다.
nonisolated struct FrameApplyResult: Equatable {
    let achieved: CGRect?
    let error: WindowCommandError?
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

    /// `resolved`가 element/appElement/pid/현재 frame을 모두 운반한다. workArea는 anchor 보정용(undo는 nil).
    static func apply(
        _ target: CGRect,
        to resolved: ResolvedWindow,
        workArea: CGRect?
    ) -> FrameApplyResult {
        // 권한 가드를 쓰기 경계에도 둔다(방어적 — 호출 순서에 의존하지 않게).
        guard AccessibilityPermissionService.currentStatus().isTrusted else {
            return FrameApplyResult(achieved: nil, error: .resolution(.permissionDenied))
        }
        let element = resolved.element
        let current = resolved.frame.rect
        let moves = FrameApply.movesOrigin(from: current, to: target)
        let resizes = FrameApply.resizesSize(from: current, to: target)
        // 실제로 바뀌는 축의 권한만 요구한다 — 이동만 하는 고정크기 창의 Move를 허용하고, 불필요한
        // size AX IPC와 부분 실패 면적을 줄인다(감사 M-3).
        if moves, !isSettable(element, kAXPositionAttribute) {
            return FrameApplyResult(achieved: nil, error: .notMovable)
        }
        if resizes, !isSettable(element, kAXSizeAttribute) {
            return FrameApplyResult(achieved: nil, error: .notResizable)
        }
        // 어느 축도 안 바뀌면 no-op — AX 쓰기 없이 현재 frame을 성공으로 반환(불필요한 쓰기·재정규화 방지).
        guard moves || resizes else {
            return FrameApplyResult(achieved: current, error: nil)
        }

        let didSuppress = suppressor.suppress(appElement: resolved.appElement, pid: resolved.pid)
        let result = writeFrame(target, to: element, current: current, workArea: workArea)
        if didSuppress { suppressor.scheduleRestore(pid: resolved.pid) }
        return result
    }

    // MARK: - 프레임 쓰기

    private static func writeFrame(
        _ target: CGRect,
        to element: AXUIElement,
        current: CGRect,
        workArea: CGRect?
    ) -> FrameApplyResult {
        // 실제로 바뀌는 축만 쓴다(권한 가드는 apply에서 이미 통과). 이동만이면 size를, 리사이즈만이면
        // position을 건드리지 않아 AX IPC와 부분 실패 면적을 줄인다(감사 M-3).
        let moves = FrameApply.movesOrigin(from: current, to: target)
        let resizes = FrameApply.resizesSize(from: current, to: target)
        let shrinking = resizes
            && (target.width < current.width - shrinkDeadband || target.height < current.height - shrinkDeadband)
        // (1) 작아질 때만 size-first: 줄인 뒤 이동해야 옛 큰 크기로 옆 모니터를 침범하지 않는다.
        if shrinking { AXAttribute.set(element, kAXSizeAttribute as String, size: target.size) }

        // (2) 이동이 있으면: 제약 앱이 목표보다 큰 크기에 머물 때 실제 크기를 읽어 anchored origin을 1회 쓴다.
        var positionError = AXError.success
        if moves {
            let origin = originForConstrainedApp(element: element, target: target, workArea: workArea)
            positionError = AXAttribute.set(element, kAXPositionAttribute as String, point: origin)
        }
        // (3) 리사이즈가 있으면 크기 재확정(모니터를 넘어가며 클램프됐을 수 있음). 이동만이면 size는 안 건드린다.
        var sizeError = AXError.success
        if resizes {
            sizeError = AXAttribute.set(element, kAXSizeAttribute as String, size: target.size)
        }

        // (4) verify + 1회 재시도(비동기·부분수용 앱). reached는 origin 2pt·size 8pt 오차 허용(증분 앱 헛재시도 방지).
        // 재시도 origin은 방금 읽힌 실제 크기로 다시 anchor 계산(첫 추정이 어긋났을 때 보정).
        // 재시도 결과를 최종 판정에 반영한다 — 재시도 중에만 생긴 일시적 실패를 success로 오분류하지 않게.
        if let achieved = readFrame(element), !FrameApply.reached(target: target, achieved: achieved) {
            if moves {
                let retryOrigin = originForConstrainedApp(element: element, target: target, workArea: workArea)
                positionError = AXAttribute.set(element, kAXPositionAttribute as String, point: retryOrigin)
            }
            if resizes {
                sizeError = AXAttribute.set(element, kAXSizeAttribute as String, size: target.size)
            }
        }

        // 최종 실제 frame을 읽는다. 읽기 실패면 결과를 알 수 없어 achieved=nil(Executor가 Undo를 건너뛴다).
        guard let achieved = readFrame(element) else {
            return FrameApplyResult(achieved: nil, error: .applyFailed)
        }
        return FrameApplyResult(achieved: achieved, error: applyError(position: positionError, size: sizeError))
    }

    /// 쓰기 결과 → UI 오류. 둘 다 성공이면 nil(제약 앱이 목표 미달이어도 성공). Space 전환·애니메이션 중
    /// cannotComplete는 transient(조용히 스킵), 그 외 실패는 applyFailed.
    private static func applyError(position: AXError, size: AXError) -> WindowCommandError? {
        if position == .success, size == .success { return nil }
        if position == .cannotComplete || size == .cannotComplete { return .transient }
        return .applyFailed
    }

    /// 제약 앱이 목표보다 크게 머물면 스냅 모서리를 유지하는 anchored origin, 아니면 목표 origin.
    /// workArea 없으면(undo) 항상 목표 origin.
    private static func originForConstrainedApp(
        element: AXUIElement,
        target: CGRect,
        workArea: CGRect?
    ) -> CGPoint {
        guard let workArea,
              let achieved = AXAttribute.size(element, kAXSizeAttribute as String),
              FrameCalculator.isConstrained(actualSize: achieved, target: target.size, tolerance: sizeTolerance)
        else { return target.origin }
        return FrameCalculator.anchorOrigin(actualSize: achieved, requested: target, workArea: workArea)
    }

    // MARK: - AX 래퍼

    private static func readFrame(_ element: AXUIElement) -> CGRect? {
        guard let origin = AXAttribute.point(element, kAXPositionAttribute as String),
              let size = AXAttribute.size(element, kAXSizeAttribute as String)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return error == .success && settable.boolValue
    }
}
