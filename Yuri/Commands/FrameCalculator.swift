import CoreGraphics

nonisolated enum FrameCalculator {
    /// 모든 사각형은 AX(좌상단 원점) 좌표. current=현재 창, workArea=작업영역.
    static func targetFrame(for command: WindowCommand, current: CGRect, workArea: CGRect) -> CGRect {
        switch command {
        case .maximize:
            workArea
        case let .absolute(placement):
            absoluteFrame(placement, current: current, workArea: workArea)
        case let .move(direction):
            moveFrame(direction, current: current, workArea: workArea)
        case let .relativeHalf(anchor):
            relativeHalfFrame(anchor, current: current)
        case .undo:
            current
        }
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
