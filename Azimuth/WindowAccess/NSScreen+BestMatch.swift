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
        var best: NSScreen?
        var bestArea: CGFloat = 0
        var bestContainsCenter = false
        var bestDisplayID: UInt32 = .max
        for screen in screens {
            let inter = cocoaRect.intersection(screen.frame)
            let area = inter.isNull ? 0 : inter.width * inter.height
            guard area > 0 else { continue }
            let containsCenter = screen.frame.contains(center)
            let displayID = screen.displayID
            let better = best == nil
                || area > bestArea + areaTieDeadband
                || (area >= bestArea - areaTieDeadband
                    && ((containsCenter && !bestContainsCenter)
                        || (containsCenter == bestContainsCenter && displayID < bestDisplayID)))
            if better {
                best = screen
                bestArea = area
                bestContainsCenter = containsCenter
                bestDisplayID = displayID
            }
        }
        return best ?? main ?? screens.first
    }

    /// CoreGraphics display ID. 열거 순서와 무관한 안정적 tie-break 키(없으면 최대값으로 폴백).
    private var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? .max
    }
}
