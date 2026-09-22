//
//  DisplayGeometry.swift
//  Azimuth
//
//  디스플레이 "선택" 순수 기하. 두 질문에 답한다 — 창이 지금 어느 화면에 있나(`bestMatchIndex`),
//  그 화면의 어느 이웃으로 갈 것인가(`selectAdjacentIndex`). 화면 frame 과 창 위치·방향만 보므로
//  NSScreen 같은 AppKit 타입에 의존하지 않아 단위 테스트가 가능하다(NSScreen+BestMatch 와
//  DisplayResolver 가 NSScreen → 값 매핑만 하는 얇은 wrapper 로 이 로직을 호출한다).
//
//  선택 규칙: ① 그 방향에 있고 수직/수평으로 겹치는 후보 중 주축 edge-gap이 가장 작은(방향상 가장
//  가까운) 인접 계층을 먼저 고른다 — "인접 디스플레이" 계약을 정렬 최적화보다 우선(먼데 정렬된
//  화면으로 leap 방지). ② 그 계층 안에서 창의 현재 수직(좌우 이동)·수평(상하 이동) 위치에 가장
//  가까운(perpendicularGap 최소) 화면. 정확히 동률이면 먼저 나온 인덱스(안정적).
//
//  순수 로직 파일 — AppKit/AX를 import하지 않는다(계층 규율, Commands/AGENTS.md). CoreGraphics·
//  SnapEdge(CommandPrimitives)만 사용. 하네스 목록은 scripts/harness-sources.sh 한 곳이다.
//

import CoreGraphics

nonisolated enum DisplaygeometryConstants {
    /// perpendicularGap 동률 판정 데드밴드(pt).
    static let tieDeadband: CGFloat = 0.5
    /// 교집합 **면적** 동률 판정 데드밴드(제곱 pt). 50:50 걸침처럼 부동소수 오차로 갈리는 동률을 흡수한다.
    /// 이름에 단위를 박는 이유: 위 `tieDeadband`는 pt 단위의 수직 간격용이라 단위도 알고리즘도 다르다.
    static let areaTieDeadbandSquarePoints: CGFloat = 1
}

/// 화면 하나를 값으로 요약한 것. `DisplayGeometry.bestMatchIndex`의 입력.
nonisolated struct ScreenCandidate: Equatable {
    /// 화면 frame(Cocoa 좌표).
    let frame: CGRect
    /// 열거 순서와 무관한 안정적 tie-break 키(CoreGraphics display ID). 없으면 `.max`.
    let displayID: UInt32
}

nonisolated enum DisplayGeometry {
    /// `window`(Cocoa 좌표)와 교집합 면적이 가장 큰 후보의 인덱스. 겹치는 후보가 없으면 nil.
    /// 면적 동률(데드밴드 이내 — 정확히 두 화면에 반씩 걸친 창 등)은 후보 순서에 의존하지 않도록
    /// 창 중심을 포함하는 후보 → 작은 displayID 순으로 결정한다.
    ///
    /// 반환값은 **`candidates` 원본 인덱스**다. 내부에서 겹침·동률로 두 번 거르므로, 거른 배열 안의
    /// 오프셋을 그대로 돌려주면 호출자가 엉뚱한 화면을 집는다(`selectAdjacentIndex`와 같은 계약).
    static func bestMatchIndex(window: CGRect, candidates: [ScreenCandidate]) -> Int? {
        let center = CGPoint(x: window.midX, y: window.midY)
        let overlapping = candidates.enumerated().compactMap { index, screen -> (index: Int, area: CGFloat)? in
            let inter = window.intersection(screen.frame)
            let area = inter.isNull ? 0 : inter.width * inter.height
            return area > 0 ? (index, area) : nil
        }
        // 최대 교집합 면적을 먼저 확정한다. 순차 비교로 기준(bestArea)을 갱신하면 동률로 이긴 후보의
        // 더 작은 면적이 기준을 낮춰(비추이적) 이후 후보의 문턱이 내려가고, 결국 열거 순서에 따라
        // 최대 면적이 아닌 화면이 뽑힐 수 있다 — 동률 규칙이 없애려던 순서 의존성이 그대로 남는다.
        guard let maxArea = overlapping.map(\.area).max() else { return nil }
        // 그 최대 면적의 데드밴드 이내(동률)인 후보들 중에서만 결정적으로 고른다:
        // 창 중심을 포함하는 후보 → 작은 displayID(둘 다 열거 순서와 무관).
        let tied = overlapping.filter { $0.area >= maxArea - DisplaygeometryConstants.areaTieDeadbandSquarePoints }
        return tied.min { lhs, rhs in
            let lhsContains = candidates[lhs.index].frame.contains(center)
            let rhsContains = candidates[rhs.index].frame.contains(center)
            if lhsContains != rhsContains { return lhsContains }
            return candidates[lhs.index].displayID < candidates[rhs.index].displayID
        }?.index
    }

    /// `current`(현재 화면 frame) 기준 `edge` 방향 인접 후보를 고른다. `candidates`는 현재 화면을
    /// 제외한 다른 화면들의 frame(Cocoa 좌표). 선택된 후보의 인덱스를 반환하고, 없으면 nil.
    /// 좌표계는 호출자가 일관되게 넘기면 무관(현재는 Cocoa: 원점 좌하단, Y 위로).
    static func selectAdjacentIndex(
        current: CGRect,
        candidates: [CGRect],
        window: CGRect,
        edge: SnapEdge
    ) -> Int? {
        // 그 방향에 있고 수직/수평으로 겹치는 후보만.
        let inDirection = candidates.enumerated().filter {
            isInDirection(origin: current, candidate: $0.element, edge: edge)
        }
        // ① 방향상 가장 가까운(주축 edge-gap 최소) 인접 계층을 먼저 확정한다.
        guard let nearestEdgeGap = inDirection
            .map({ primaryEdgeGap(origin: current, candidate: $0.element, edge: edge) })
            .min()
        else { return nil }

        // ② 그 계층(edge-gap ≈ 최소) 안에서 창 정렬(perpendicular gap)이 **최소**인 화면을 고른다.
        //    정확히 동률이면 먼저 나온 인덱스가 이긴다. 비교에 데드밴드를 쓰면 안 된다 — 순차 비교가
        //    비추이적이 되어(각 단계가 직전 승자와만 비교) 후보 순서에 따라 최소가 아닌 화면이 뽑힌다
        //    (예: gap [1.2, 0.8, 0.4, 0.0] → 0.4 선택, 순서를 뒤집으면 0.0 선택).
        let deadband = DisplaygeometryConstants.tieDeadband
        var best: Int?
        var bestPerpendicular = CGFloat.greatestFiniteMagnitude
        for (index, candidate) in inDirection {
            let edgeGap = primaryEdgeGap(origin: current, candidate: candidate, edge: edge)
            guard edgeGap <= nearestEdgeGap + deadband else { continue }
            let perpendicular = perpendicularGap(window: window, candidate: candidate, edge: edge)
            if best == nil || perpendicular < bestPerpendicular {
                best = index
                bestPerpendicular = perpendicular
            }
        }
        return best
    }

    /// `edge` 방향에 있고 수직/수평으로 겹치는가. 그 방향의 모든 화면이 후보(물리적 인접 한정 아님);
    /// 최종 선택은 거리 기준(가장 가까운 화면이 이긴다).
    static func isInDirection(origin: CGRect, candidate: CGRect, edge: SnapEdge) -> Bool {
        switch edge {
        case .left:
            return candidate.midX < origin.midX && verticalOverlap(origin, candidate)
        case .right:
            return candidate.midX > origin.midX && verticalOverlap(origin, candidate)
        case .top:
            return candidate.midY > origin.midY && horizontalOverlap(origin, candidate)
        case .bottom:
            return candidate.midY < origin.midY && horizontalOverlap(origin, candidate)
        }
    }

    /// 창의 수직(좌우 이동)·수평(상하 이동) 중심이 후보 화면 범위에서 벗어난 거리(범위 안이면 0).
    static func perpendicularGap(window: CGRect, candidate: CGRect, edge: SnapEdge) -> CGFloat {
        switch edge {
        case .left, .right:
            return distance(window.midY, lower: candidate.minY, upper: candidate.maxY)
        case .top, .bottom:
            return distance(window.midX, lower: candidate.minX, upper: candidate.maxX)
        }
    }

    /// 이동 방향(주축)에서 현재 화면과 후보 화면 사이의 edge-to-edge 간격(겹치면 음수). 값이 작을수록
    /// 방향상 더 가까운(더 인접한) 화면. 중심 거리 대신 이 간격으로 "인접 계층"을 판정한다.
    static func primaryEdgeGap(origin: CGRect, candidate: CGRect, edge: SnapEdge) -> CGFloat {
        switch edge {
        case .left:
            return origin.minX - candidate.maxX
        case .right:
            return candidate.minX - origin.maxX
        case .top:
            return candidate.minY - origin.maxY
        case .bottom:
            return origin.minY - candidate.maxY
        }
    }

    private static func distance(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        if value < lower { return lower - value }
        if value > upper { return value - upper }
        return 0
    }

    private static func verticalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        lhs.minY < rhs.maxY && rhs.minY < lhs.maxY
    }

    private static func horizontalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        lhs.minX < rhs.maxX && rhs.minX < lhs.maxX
    }
}
