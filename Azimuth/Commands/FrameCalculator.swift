import CoreGraphics

nonisolated enum FrameCalculator {
    /// 모든 사각형은 AX(좌상단 원점) 좌표. current=현재 창, workArea=작업영역.
    static func targetFrame(for command: WindowCommand, current: CGRect, workArea: CGRect) -> CGRect {
        switch command {
        case .maximize:
            workArea
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
            relativeHalfFrame(anchor, current: current)
        case .undo:
            current
        }
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

    /// 창이 그 방향 절반을 (대체로) 채우고 있는가. snapThrow의 "이미 절반 → 튕기기" 트리거에 쓴다.
    /// 판정: ① 그 절반 영역에 대체로 담겨 있고(반대쪽/화면 밖으로 tolerance 이상 넘치지 않음),
    /// ② 절반 면적의 minCoverage 이상을 덮는다. 절반보다 작은 창은 ②에서 걸러져 "채움"이 아니다(→ 스냅).
    /// 크기증분 앱(터미널 등)은 far edge가 한 셀 모자라도 커버리지가 높아 통과한다. 모든 방향 동일 규칙.
    static func fillsHalf(
        _ rect: CGRect,
        edge: SnapEdge,
        workArea: CGRect,
        tolerance: CGFloat = 20,
        minCoverage: CGFloat = 0.9
    ) -> Bool {
        let half = halfRect(edge, workArea: workArea)
        guard half.width > 0, half.height > 0 else { return false }
        let contained = rect.minX >= half.minX - tolerance
            && rect.maxX <= half.maxX + tolerance
            && rect.minY >= half.minY - tolerance
            && rect.maxY <= half.maxY + tolerance
        guard contained else { return false }
        let inter = rect.intersection(half)
        guard !inter.isNull else { return false }
        let coverage = (inter.width * inter.height) / (half.width * half.height)
        return coverage >= minCoverage
    }

    /// 현재 창을 `from` 작업영역 기준 상대 위치·크기를 유지한 채 `to` 작업영역으로 옮긴다(다음 디스플레이 이동).
    /// 크기는 대상 화면을 넘지 않게 캡(비율 1.0)하고, 위치는 대상 영역 안으로 클램프한다.
    /// `from`이 너비 또는 높이가 0인 퇴화 사각형이면 `destination` 전체를 반환한다(창이 대상 화면을 채움).
    static func displayMoveRect(_ rect: CGRect, from: CGRect, to destination: CGRect) -> CGRect {
        guard from.width > 0, from.height > 0 else { return destination }
        let relativeX = (rect.minX - from.minX) / from.width
        let relativeY = (rect.minY - from.minY) / from.height
        let width = Swift.min(rect.width / from.width, 1) * destination.width
        let height = Swift.min(rect.height / from.height, 1) * destination.height
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
            origin.x = workArea.minX + (workArea.width - current.width) / 2
            origin.y = workArea.minY + (workArea.height - current.height) / 2
        }
        return CGRect(origin: origin, size: current.size)
    }

    /// 값을 [lower, upper] 범위로 클램프. 창이 작업영역보다 커서 upper<lower면 lower(좌상단)에 고정.
    private static func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard upper > lower else { return lower }
        return Swift.max(lower, Swift.min(upper, value))
    }

    // MARK: - 상대 변형 (현재 frame 기준, 방향 edge 고정)

    private static func relativeHalfFrame(_ anchor: RelativeAnchor, current: CGRect) -> CGRect {
        let halfWidth = current.width / 2
        let halfHeight = current.height / 2
        switch anchor {
        case .left:
            return CGRect(x: current.minX, y: current.minY, width: halfWidth, height: current.height)
        case .right:
            return CGRect(x: current.maxX - halfWidth, y: current.minY, width: halfWidth, height: current.height)
        case .top:
            return CGRect(x: current.minX, y: current.minY, width: current.width, height: halfHeight)
        case .bottom:
            return CGRect(x: current.minX, y: current.maxY - halfHeight, width: current.width, height: halfHeight)
        }
    }
}
