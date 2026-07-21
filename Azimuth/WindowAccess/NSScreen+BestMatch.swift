//
//  NSScreen+BestMatch.swift
//  Azimuth
//
//  Cocoa 좌표 사각형과 가장 많이 겹치는 화면 선택. WorkAreaResolver·DisplayResolver가
//  각자 복사해 쓰던 동일 로직을 한 곳으로 모았다.
//

import AppKit

extension NSScreen {
    /// 교집합 면적 동률(50:50 걸침 등)에서 화면 열거 순서에 의존하지 않도록 하는 데드밴드(제곱 pt).
    private static let areaTieDeadband: CGFloat = 1

    /// `cocoaRect`(Cocoa 좌표)와 교집합 면적이 가장 큰 화면. 겹치는 화면이 없으면 main → 첫 화면으로 폴백.
    /// 면적 동률(정확히 두 화면에 반씩 걸친 창 등)이면 `NSScreen.screens` 순서에 의존하지 않도록
    /// ① 창 중심을 포함하는 화면 → ② 작은 displayID 순으로 결정한다.
    /// `NSScreen.screens` 접근이 메인 액터 격리이므로 @MainActor.
    @MainActor
    static func bestMatch(forCocoaRect cocoaRect: CGRect) -> NSScreen? {
        let center = CGPoint(x: cocoaRect.midX, y: cocoaRect.midY)
        let overlapping = screens.compactMap { screen -> (screen: NSScreen, area: CGFloat)? in
            let inter = cocoaRect.intersection(screen.frame)
            let area = inter.isNull ? 0 : inter.width * inter.height
            return area > 0 ? (screen, area) : nil
        }
        // ① 최대 교집합 면적을 먼저 확정한다. 순차 비교로 기준(bestArea)을 갱신하면 동률로 이긴 화면의
        //    더 작은 면적이 기준을 낮춰(비추이적) 이후 후보의 문턱이 내려가고, 결국 열거 순서에 따라
        //    최대 면적이 아닌 화면이 뽑힐 수 있다 — L-1이 없애려던 순서 의존성이 그대로 남는다.
        guard let maxArea = overlapping.map({ $0.area }).max() else { return main ?? screens.first }
        // ② 그 최대 면적의 데드밴드 이내(동률)인 화면들 중에서만 결정적으로 고른다:
        //    창 중심을 포함하는 화면 → 작은 displayID(둘 다 열거 순서와 무관).
        let tied = overlapping.filter { $0.area >= maxArea - areaTieDeadband }
        return tied.min { lhs, rhs in
            let lhsContains = lhs.screen.frame.contains(center)
            let rhsContains = rhs.screen.frame.contains(center)
            if lhsContains != rhsContains { return lhsContains }
            return lhs.screen.displayID < rhs.screen.displayID
        }?.screen ?? main ?? screens.first
    }

    /// CoreGraphics display ID. 열거 순서와 무관한 안정적 tie-break 키(없으면 최대값으로 폴백).
    private var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? .max
    }
}
