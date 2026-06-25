//
//  DisplayResolver.swift
//  Azimuth
//
//  현재 창이 놓인 화면 기준으로, 지정 방향에 인접한 디스플레이의 작업영역을 구한다.
//  snap-or-throw·다음 디스플레이 이동에서 사용. 좌표 변환은 CoordinateSpace 재사용.
//
//  인접 선택은 "위치 인식형"이다: 그 방향에 있고 현재 화면과 수직/수평으로 겹치는 후보 중,
//  창의 현재 수직(좌우 이동) 또는 수평(상하 이동) 위치에 가장 가까운 화면을 고른다.
//  (세로로 긴 모니터 왼쪽에 두 화면이 위아래로 있을 때, 창 높이에 맞는 쪽으로 가게 한다.)
//

import AppKit

@MainActor
enum DisplayResolver {
    /// AX 창 frame이 놓인 화면 기준으로 `edge` 방향 인접 화면의 visibleFrame을 AX 좌표로 반환. 없으면 nil.
    /// @MainActor: 열거형 전체가 @MainActor이므로 이 메서드도 메인 액터에서만 호출 가능 (`NSScreen.screens` 접근).
    static func adjacentWorkArea(forAXWindowFrame axFrame: CGRect, edge: SnapEdge) -> CGRect? {
        let cocoaWindow = CoordinateSpace.axToCocoa(axFrame)
        guard let current = bestScreen(for: cocoaWindow),
              let neighbor = adjacentScreen(to: current, edge: edge, window: cocoaWindow)
        else {
            return nil
        }
        return CoordinateSpace.cocoaToAX(neighbor.visibleFrame)
    }

    private static func bestScreen(for cocoaRect: CGRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let rect = cocoaRect.intersection(screen.frame)
            let area = rect.isNull ? 0 : rect.width * rect.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// 방향에 맞고 현재 화면과 겹치는 후보 중, 창 위치에 수직/수평으로 가장 가까운 화면.
    /// 동률이면 주축(이동 방향) 중심 거리가 가까운 쪽으로 결정.
    private static func adjacentScreen(to current: NSScreen, edge: SnapEdge, window: CGRect) -> NSScreen? {
        let origin = current.frame
        var best: NSScreen?
        var bestPerpendicular = CGFloat.greatestFiniteMagnitude
        var bestPrimary = CGFloat.greatestFiniteMagnitude
        for screen in NSScreen.screens where screen != current {
            let candidate = screen.frame
            guard isInDirection(origin: origin, candidate: candidate, edge: edge) else { continue }
            let perpendicular = perpendicularGap(window: window, candidate: candidate, edge: edge)
            let primary = primaryGap(origin: origin, candidate: candidate, edge: edge)
            let closerPerpendicular = perpendicular < bestPerpendicular - 0.5
            let tiedPerpendicular = abs(perpendicular - bestPerpendicular) <= 0.5 && primary < bestPrimary
            if closerPerpendicular || tiedPerpendicular {
                bestPerpendicular = perpendicular
                bestPrimary = primary
                best = screen
            }
        }
        return best
    }

    /// Cocoa 좌표(원점 좌하단, Y 위로)에서 `edge` 방향에 있고 수직/수평으로 겹치는가.
    /// 물리적으로 인접한 화면만이 아니라 그 방향에 있는 모든 화면이 후보가 된다.
    /// 최종 선택은 `perpendicularGap`·`primaryGap` 거리 기준으로 이루어진다(가장 가까운 화면이 이긴다).
    private static func isInDirection(origin: CGRect, candidate: CGRect, edge: SnapEdge) -> Bool {
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
    private static func perpendicularGap(window: CGRect, candidate: CGRect, edge: SnapEdge) -> CGFloat {
        switch edge {
        case .left, .right:
            return distance(window.midY, lower: candidate.minY, upper: candidate.maxY)
        case .top, .bottom:
            return distance(window.midX, lower: candidate.minX, upper: candidate.maxX)
        }
    }

    /// 이동 방향(주축) 중심 거리. 동률 타이브레이크에 쓴다.
    private static func primaryGap(origin: CGRect, candidate: CGRect, edge: SnapEdge) -> CGFloat {
        switch edge {
        case .left:
            return origin.midX - candidate.midX
        case .right:
            return candidate.midX - origin.midX
        case .top:
            return candidate.midY - origin.midY
        case .bottom:
            return origin.midY - candidate.midY
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
