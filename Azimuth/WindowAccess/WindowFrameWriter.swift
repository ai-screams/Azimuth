import ApplicationServices

/// AX 쓰기는 메인 스레드에서만 안전하며 권한 캐시(@MainActor)와 애니메이션 억제 상태를 다루므로 @MainActor.
///
/// 쓰기 전략(메이저 윈도우 매니저 컨센서스):
///  - `AnimationSuppressor`로 대상 앱의 애니메이션 속성을 잠시 꺼서 AX 쓰기를 동기·비애니메이션화한다(깜빡임 제거).
///  - 작아질 때만 size→position 순서(줄인 뒤 이동 → 옛 큰 크기로 옆 모니터 침범 방지), 커질 땐 position→size.
///  - 제약 앱이 목표 크기에 못 미치면 실제 크기를 읽어 anchored origin을 "한 번만" 써서(KI-003 2단계 깜빡임 회피)
///    스냅 모서리를 유지한다.
@MainActor
enum WindowFrameWriter {
    private static let originTolerance: CGFloat = 2
    /// 크기증분 앱(Terminal)이 한 셀(≈7pt) 모자라도 헛재시도하지 않게 size 허용 오차는 넉넉히.
    private static let sizeTolerance: CGFloat = 8
    /// shrink 판정 데드밴드(반올림 오차로 같은 크기가 미세하게 작게 읽히는 것을 무시).
    private static let shrinkDeadband: CGFloat = 1

    /// 애니메이션 억제 상태(PID별)는 명령 간 유지되어야 하므로 writer가 단일 인스턴스로 소유한다.
    private static let suppressor = AnimationSuppressor()

    /// `resolved`가 element/appElement/pid/현재 frame을 모두 운반한다. workArea는 anchor 보정용(undo는 nil).
    static func apply(
        _ target: CGRect,
        to resolved: ResolvedWindow,
        workArea: CGRect?
    ) -> Result<CGRect, WindowCommandError> {
        // 권한 가드를 쓰기 경계에도 둔다(방어적 — 호출 순서에 의존하지 않게).
        guard AccessibilityPermissionService.currentStatus().isTrusted else {
            return .failure(.resolution(.permissionDenied))
        }
        let element = resolved.element
        guard isSettable(element, kAXPositionAttribute), isSettable(element, kAXSizeAttribute) else {
            return .failure(.notMovable)
        }

        let didSuppress = suppressor.suppress(appElement: resolved.appElement, pid: resolved.pid)
        let result = writeFrame(target, to: element, current: resolved.frame.rect, workArea: workArea)
        if didSuppress { suppressor.scheduleRestore(pid: resolved.pid) }
        return result
    }

    // MARK: - 프레임 쓰기

    private static func writeFrame(
        _ target: CGRect,
        to element: AXUIElement,
        current: CGRect,
        workArea: CGRect?
    ) -> Result<CGRect, WindowCommandError> {
        let shrinking = target.width < current.width - shrinkDeadband || target.height < current.height - shrinkDeadband
        // (1) 작아질 때만 size-first: 줄인 뒤 이동해야 옛 큰 크기로 옆 모니터를 침범하지 않는다.
        if shrinking { AXAttribute.set(element, kAXSizeAttribute as String, size: target.size) }

        // (2) 제약 앱이 목표보다 큰 크기에 머물면 실제 크기를 읽어 anchored origin을 "한 번만" 쓴다(위치 1회).
        let origin = originForConstrainedApp(element: element, target: target, workArea: workArea)
        let positionError = AXAttribute.set(element, kAXPositionAttribute as String, point: origin)
        // (3) 크기 재확정(모니터를 넘어가며 클램프됐을 수 있음).
        let sizeError = AXAttribute.set(element, kAXSizeAttribute as String, size: target.size)

        // (4) verify + 1회 재시도(비동기·부분수용 앱). size는 8pt 오차 허용(증분 앱 헛재시도 방지).
        // 재시도 origin은 방금 읽힌 실제 크기로 다시 anchor 계산(첫 추정이 어긋났을 때 보정).
        if let achieved = readFrame(element), !frameMatches(achieved, origin: origin, size: target.size) {
            let retryOrigin = originForConstrainedApp(element: element, target: target, workArea: workArea)
            AXAttribute.set(element, kAXPositionAttribute as String, point: retryOrigin)
            AXAttribute.set(element, kAXSizeAttribute as String, size: target.size)
        }

        guard positionError == .success, sizeError == .success else {
            // Space 전환·애니메이션 중엔 cannotComplete가 흔하다 → 일시적 실패로 구분(조용히 스킵).
            let isTransient = positionError == .cannotComplete || sizeError == .cannotComplete
            return .failure(isTransient ? .transient : .applyFailed)
        }
        guard let achieved = readFrame(element) else { return .failure(.applyFailed) }
        return .success(achieved)
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
              achieved.width > target.width + sizeTolerance || achieved.height > target.height + sizeTolerance
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

    /// 읽어온 frame이 목표 origin·size에 (허용오차 내) 도달했는가. 재시도 판정에 쓴다.
    private static func frameMatches(_ frame: CGRect, origin: CGPoint, size: CGSize) -> Bool {
        approx(frame.origin, origin, tol: originTolerance) && approx(frame.size, size, tol: sizeTolerance)
    }

    private static func approx(_ lhs: CGPoint, _ rhs: CGPoint, tol: CGFloat) -> Bool {
        abs(lhs.x - rhs.x) <= tol && abs(lhs.y - rhs.y) <= tol
    }

    private static func approx(_ lhs: CGSize, _ rhs: CGSize, tol: CGFloat) -> Bool {
        abs(lhs.width - rhs.width) <= tol && abs(lhs.height - rhs.height) <= tol
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return error == .success && settable.boolValue
    }
}
