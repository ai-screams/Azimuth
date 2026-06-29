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
            relativeFrame(anchor, fraction: 1.0 / 2.0, current: current)
        case let .relativeTwoThird(anchor):
            relativeFrame(anchor, fraction: 2.0 / 3.0, current: current)
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

    /// 창이 그 방향 절반에 "스냅된 상태"인가. snapThrow의 "이미 절반 → 튕기기" 트리거에 쓴다.
    /// 판정(4변 대칭): ① 그 방향 바깥(화면) 모서리에 붙어 있고(단방향 — 화면 밖 overflow는 허용),
    /// ② 반대쪽 바깥 모서리에는 닿지 않으며(최대화·양쪽 걸침 제외 → 그땐 스냅),
    /// ③ 스냅 축과 수직인 축을 작업영역의 절반 이상 덮는다(모서리에 살짝 닿은 소형 부유창 오판 방지).
    /// 주축(스냅 방향)은 flush만 보므로 고정폭·최소폭 앱도 한쪽에 붙어 있으면 "스냅됨"으로 인정된다
    /// — 좌우/상하 대칭으로 throw가 가능해진다(면적 커버리지 기반의 좌우 비대칭 버그 제거).
    static func isSnapped(_ rect: CGRect, to edge: SnapEdge, workArea: CGRect) -> Bool {
        outerFlush(rect, edge: edge, workArea: workArea)
            && !outerFlush(rect, edge: edge.opposite, workArea: workArea)
            && spansPerpendicular(rect, edge: edge, workArea: workArea)
    }

    /// 스냅 축과 수직인 축(좌우 스냅이면 높이, 상하면 너비)을 작업영역의 절반 이상 덮는가.
    /// 주축은 flush로만 판정하므로 고정폭/최소폭 앱은 통과하고, 모서리에 살짝 닿은 소형 부유창만 걸러진다.
    private static func spansPerpendicular(_ rect: CGRect, edge: SnapEdge, workArea: CGRect) -> Bool {
        let span: CGFloat
        let extent: CGFloat
        switch edge {
        case .left, .right:
            span = overlap(rect.minY, rect.maxY, workArea.minY, workArea.maxY)
            extent = workArea.height
        case .top, .bottom:
            span = overlap(rect.minX, rect.maxX, workArea.minX, workArea.maxX)
            extent = workArea.width
        }
        // 퇴화 작업영역(높이/너비 0 — 디스플레이 재구성 순간 등)에서 0 나눗셈(NaN) 방지.
        guard extent > 0 else { return false }
        return span / extent >= 0.5
    }

    /// 두 1차원 구간 [aMin,aMax]·[bMin,bMax]의 겹치는 길이(겹침 없으면 0).
    private static func overlap(_ aMin: CGFloat, _ aMax: CGFloat, _ bMin: CGFloat, _ bMax: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(aMax, bMax) - Swift.max(aMin, bMin))
    }

    /// 그 방향 바깥(화면) 모서리에 붙었는가. 단방향: 화면 밖으로 넘쳐도(앱 최소 크기 탓) 붙은 것으로 본다.
    /// tolerance는 작업영역 크기에 비례(작은 모니터의 크기증분 앱 한 셀 오차 대응) — 최소 8pt.
    private static func outerFlush(_ rect: CGRect, edge: SnapEdge, workArea: CGRect) -> Bool {
        switch edge {
        case .left:
            return rect.minX <= workArea.minX + tolerance(workArea.width)
        case .right:
            return rect.maxX >= workArea.maxX - tolerance(workArea.width)
        case .top:
            return rect.minY <= workArea.minY + tolerance(workArea.height)
        case .bottom:
            return rect.maxY >= workArea.maxY - tolerance(workArea.height)
        }
    }

    /// 절대 픽셀 대신 작업영역 비례(1%) tolerance. 모니터가 작아도 한 셀(≈8pt) 이상은 보장.
    private static func tolerance(_ extent: CGFloat) -> CGFloat {
        Swift.max(8, extent * 0.01)
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

    /// 현재 창을 `fraction` 배율로 축소하되 `anchor` 모서리를 고정한다(나머지 축은 유지).
    /// 좌우 anchor는 너비를, 상하 anchor는 높이를 줄인다. fraction을 바꿔 1/2·2/3 등을 공유한다.
    /// 효과 조합 가능: 2/3 후 1/2 = 1/3 (절대 1/3 없이도 상대적으로 도달).
    private static func relativeFrame(_ anchor: RelativeAnchor, fraction: CGFloat, current: CGRect) -> CGRect {
        let newWidth = current.width * fraction
        let newHeight = current.height * fraction
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
