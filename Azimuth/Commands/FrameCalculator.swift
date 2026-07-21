import CoreGraphics

nonisolated enum FrameCalculator {
    /// 모든 사각형은 AX(좌상단 원점) 좌표. current=현재 창, workArea=작업영역.
    static func targetFrame(for command: WindowCommand, current: CGRect, workArea: CGRect) -> CGRect {
        switch command {
        case .maximize:
            workArea
        case .maximizeGaps:
            gappedWorkArea(workArea)
        case let .absolute(placement):
            absoluteFrame(placement, current: current, workArea: workArea)
        case let .snapThrow(edge):
            // 순수 폴백 = 그 방향 절반(스냅). 인접 디스플레이로 던지는 분기는 Executor가 처리한다.
            halfRect(edge, workArea: workArea)
        case .moveToDisplay:
            // 인접 디스플레이가 필요하므로 Executor가 처리한다. 폴백(인접 없음)은 현 위치 유지.
            current
        case let .move(direction):
            moveFrame(direction, current: current, workArea: workArea)
        case let .relativeHalf(anchor):
            relativeFrame(anchor, fraction: 1.0 / 2.0, current: current)
        case let .relativeTwoThird(anchor):
            relativeFrame(anchor, fraction: 2.0 / 3.0, current: current)
        case .undo:
            current
        }
    }

    // MARK: - 여백 최대화 (작업영역을 사방 gap만큼 안쪽으로)

    /// Maximize와 달리 화면 가장자리에 붙지 않고 사방 gap을 남기고 채운다.
    private static let maximizeGapInset: CGFloat = 12
    /// 여백 최대화 폴백 하한(전용). 상대축소의 minRelativeExtent와 값은 같지만 관심사가 달라
    /// 따로 둔다 — 한쪽 튜닝이 다른 쪽 동작을 흔들지 않게 한다.
    private static let maximizeGapMinExtent: CGFloat = 100

    /// 작업영역을 사방 `maximizeGapInset`만큼 축소한 사각형. 단, 작은 작업영역·과도한 gap으로
    /// 결과 한 변이 maximizeGapMinExtent(100pt) 미만이 되면(0/음수 크기 방지) 평범한 maximize(workArea)로 폴백.
    private static func gappedWorkArea(_ workArea: CGRect) -> CGRect {
        let inset = workArea.insetBy(dx: maximizeGapInset, dy: maximizeGapInset)
        guard inset.width >= maximizeGapMinExtent, inset.height >= maximizeGapMinExtent else { return workArea }
        return inset
    }

    // MARK: - 절반 (snap/throw 공용; AX 좌표 — 상단 원점)

    /// 작업영역 기준 그 방향 절반 사각형. 스냅 타깃과 "이미 절반인가" 비교에 공용으로 쓴다.
    static func halfRect(_ edge: SnapEdge, workArea: CGRect) -> CGRect {
        let halfWidth = workArea.width / 2
        let halfHeight = workArea.height / 2
        switch edge {
        case .left:
            return CGRect(x: workArea.minX, y: workArea.minY, width: halfWidth, height: workArea.height)
        case .right:
            return CGRect(x: workArea.midX, y: workArea.minY, width: halfWidth, height: workArea.height)
        case .top:
            return CGRect(x: workArea.minX, y: workArea.minY, width: workArea.width, height: halfHeight)
        case .bottom:
            return CGRect(x: workArea.minX, y: workArea.midY, width: workArea.width, height: halfHeight)
        }
    }

    /// snapThrow의 "이미 그 방향에 스냅됨 → 인접 디스플레이로 던지기" 트리거. 두 경로로만 인정한다(감사 H-2):
    ///  ① 현재 창이 그 방향 절반과 (엄격히) 일치 — 정확히 반쪽인 창.
    ///  ② Azimuth가 이 창을 그 edge로 스냅했고(recorded) 그 뒤 외부에서 안 움직임 — 제약 앱(정확한 반쪽에
    ///     못 미쳐도) 대응. 둘 다 아니면(수동으로 좁게/멀리/화면 밖에 둔 창) 첫 입력에 스냅되고 던져지지 않는다.
    static func isAlreadySnapped(current: CGRect, edge: SnapEdge, workArea: CGRect, recorded: SnapRecord?) -> Bool {
        if FrameApply.reached(target: halfRect(edge, workArea: workArea), achieved: current) { return true }
        if let recorded, recorded.edge == edge, FrameApply.reached(target: recorded.frame, achieved: current) {
            return true
        }
        return false
    }

    /// 앱이 목표보다 "제약적으로 큰"(어느 한 축이라도 tolerance 초과) 상태인가 — anchored origin
    /// 보정을 걸지 판정한다. 순수 함수라 경계값(tolerance 직전/직후)을 테스트할 수 있다.
    static func isConstrained(actualSize: CGSize, target: CGSize, tolerance: CGFloat) -> Bool {
        actualSize.width > target.width + tolerance || actualSize.height > target.height + tolerance
    }

    /// AX에서 읽은 frame이 사용 가능한가 — 좌표·크기가 모두 유한하고 크기가 양수인가. NaN·무한·0·음수
    /// frame(비정상 앱·화면 전환 순간)이 fallback·잘못된 target 계산으로 새는 것을 막는 방어벽.
    static func isUsableFrame(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.size.width.isFinite && rect.size.height.isFinite
            && rect.size.width > 0 && rect.size.height > 0
    }

    /// 제약 앱이 목표 크기에 못 미칠 때, target이 닿아 있던 작업영역 모서리를 실제 크기에 맞춰 유지하는 origin.
    /// 위치를 두 번 쓰지 않고(KI-003 깜빡임 회피) 처음부터 이 anchored origin으로 단 한 번 쓰기 위해 사용.
    /// touching 모서리는 target·workArea에서 내부 도출한다(호출자가 넘기지 않음).
    static func anchorOrigin(
        actualSize: CGSize,
        requested target: CGRect,
        workArea: CGRect,
        epsilon: CGFloat = 2
    ) -> CGPoint {
        let touchesLeft = target.minX <= workArea.minX + epsilon
        let touchesRight = target.maxX >= workArea.maxX - epsilon
        let touchesTop = target.minY <= workArea.minY + epsilon
        let touchesBottom = target.maxY >= workArea.maxY - epsilon
        let x = (touchesRight && !touchesLeft) ? workArea.maxX - actualSize.width : target.minX
        let y = (touchesBottom && !touchesTop) ? workArea.maxY - actualSize.height : target.minY
        // 앱 최소 크기가 작업영역보다 큰 퇴화 케이스: origin이 화면 밖(음수)으로 가지 않게 좌상단으로 클램프.
        return CGPoint(x: Swift.max(workArea.minX, x), y: Swift.max(workArea.minY, y))
    }

    /// 명시적 anchor 의도에 따라, 앱이 실제로 취한 크기(actualSize)에 맞춰 고정 모서리를 유지하는 origin.
    /// 상대 축소(right/bottom)는 앱이 요청보다 작게/크게 반올림해도 그 모서리를 고정한다 — 작업영역
    /// 모서리에 닿지 않은 창도 복구되므로 반복 축소의 셀 단위 드리프트가 생기지 않는다(감사 M-4).
    /// workAreaEdges는 target이 닿아 있던 작업영역 모서리를 추론해 유지한다(스냅·절대 배치).
    static func anchoredOrigin(
        anchor: FrameAnchor,
        actualSize: CGSize,
        target: CGRect,
        workArea: CGRect
    ) -> CGPoint {
        switch anchor {
        case .topLeft:
            return target.origin
        case .right:
            return CGPoint(x: target.maxX - actualSize.width, y: target.minY)
        case .bottom:
            return CGPoint(x: target.minX, y: target.maxY - actualSize.height)
        case .workAreaEdges:
            return anchorOrigin(actualSize: actualSize, requested: target, workArea: workArea)
        }
    }

    /// 현재 창을 `from` 작업영역 기준 상대 위치를 유지한 채 `to` 작업영역으로 옮긴다(다음 디스플레이 이동).
    /// 크기는 창의 절대(픽셀) 크기를 유지하되 대상 화면을 넘지 않게 캡하고, 위치는 대상 영역 안으로 클램프한다.
    /// 화면 비율이 달라도 창의 모양(종횡비)·크기가 보존된다(대상 화면보다 큰 축만 대상 크기로 축소).
    /// `from`이 너비 또는 높이가 0인 퇴화 사각형이면 `destination` 전체를 반환한다(창이 대상 화면을 채움).
    static func displayMoveRect(_ rect: CGRect, from: CGRect, to destination: CGRect) -> CGRect {
        guard from.width > 0, from.height > 0 else { return destination }
        let relativeX = (rect.minX - from.minX) / from.width
        let relativeY = (rect.minY - from.minY) / from.height
        let width = Swift.min(rect.width, destination.width)
        let height = Swift.min(rect.height, destination.height)
        let originX = clamped(destination.minX + relativeX * destination.width,
                              lower: destination.minX, upper: destination.maxX - width)
        let originY = clamped(destination.minY + relativeY * destination.height,
                              lower: destination.minY, upper: destination.maxY - height)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    // MARK: - 절대 배치 (축 독립)

    private static func absoluteFrame(
        _ placement: AbsolutePlacement,
        current: CGRect,
        workArea: CGRect
    ) -> CGRect {
        let horizontal = placement.axis == .horizontal
        let length = horizontal ? workArea.width : workArea.height
        let origin = horizontal ? workArea.minX : workArea.minY
        let size = length * placement.fraction.value
        let position = slotPosition(placement.slot, origin: origin, length: length, size: size)

        if horizontal {
            return CGRect(x: position, y: current.minY, width: size, height: current.height)
        }
        return CGRect(x: current.minX, y: position, width: current.width, height: size)
    }

    private static func slotPosition(_ slot: Slot, origin: CGFloat, length: CGFloat, size: CGFloat) -> CGFloat {
        switch slot {
        case .first:
            origin
        case .center:
            origin + (length - size) / 2
        case .last:
            origin + (length - size)
        }
    }

    // MARK: - 이동 (현재 크기 유지, 단위=현재 창 크기, 작업영역 클램프)

    private static func moveFrame(_ direction: MoveDirection, current: CGRect, workArea: CGRect) -> CGRect {
        let xLower = workArea.minX
        let xUpper = workArea.maxX - current.width
        let yLower = workArea.minY
        let yUpper = workArea.maxY - current.height
        var origin = current.origin
        switch direction {
        case .left:
            origin.x = clamped(current.minX - current.width, lower: xLower, upper: xUpper)
        case .right:
            origin.x = clamped(current.minX + current.width, lower: xLower, upper: xUpper)
        case .up:
            origin.y = clamped(current.minY - current.height, lower: yLower, upper: yUpper)
        case .down:
            origin.y = clamped(current.minY + current.height, lower: yLower, upper: yUpper)
        case .center:
            // 방향 이동과 동일하게 clamp 경유 — 작업영역보다 큰 창이 음수 origin(화면 밖)으로 가지 않게.
            origin.x = clamped(workArea.minX + (workArea.width - current.width) / 2, lower: xLower, upper: xUpper)
            origin.y = clamped(workArea.minY + (workArea.height - current.height) / 2, lower: yLower, upper: yUpper)
        }
        return CGRect(origin: origin, size: current.size)
    }

    /// 값을 [lower, upper] 범위로 클램프. 창이 작업영역보다 커서 upper<lower면 lower(좌상단)에 고정.
    private static func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard upper > lower else { return lower }
        return Swift.max(lower, Swift.min(upper, value))
    }

    // MARK: - 상대 변형 (현재 frame 기준, 방향 edge 고정)

    /// 반복 상대 축소가 창을 0으로 수렴시키지 않도록 한 변의 하한(pt). 이보다 작아지지 않는다
    /// (이미 이보다 작은 창은 그대로 둔다 — 확대는 하지 않음). 고정/최소크기 앱에서 앵커가 위치만
    /// 밀어 생기는 드리프트도 완화한다.
    private static let minRelativeExtent: CGFloat = 100

    /// 현재 창을 `fraction` 배율로 축소하되 `anchor` 모서리를 고정한다(나머지 축은 유지).
    /// 좌우 anchor는 너비를, 상하 anchor는 높이를 줄인다. fraction을 바꿔 1/2·2/3 등을 공유한다.
    /// 효과 조합 가능: 2/3 후 1/2 = 1/3 (절대 1/3 없이도 상대적으로 도달). 한 변은 minRelativeExtent 하한.
    private static func relativeFrame(_ anchor: RelativeAnchor, fraction: CGFloat, current: CGRect) -> CGRect {
        let newWidth = Swift.max(current.width * fraction, Swift.min(current.width, minRelativeExtent))
        let newHeight = Swift.max(current.height * fraction, Swift.min(current.height, minRelativeExtent))
        switch anchor {
        case .left:
            return CGRect(x: current.minX, y: current.minY, width: newWidth, height: current.height)
        case .right:
            return CGRect(x: current.maxX - newWidth, y: current.minY, width: newWidth, height: current.height)
        case .top:
            return CGRect(x: current.minX, y: current.minY, width: current.width, height: newHeight)
        case .bottom:
            return CGRect(x: current.minX, y: current.maxY - newHeight, width: current.width, height: newHeight)
        }
    }
}
