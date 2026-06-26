//
//  NSScreen+BestMatch.swift
//  Azimuth
//
//  Cocoa 좌표 사각형과 가장 많이 겹치는 화면 선택. WorkAreaResolver·DisplayResolver가
//  각자 복사해 쓰던 동일 로직을 한 곳으로 모았다.
//

import AppKit

extension NSScreen {
    /// `cocoaRect`(Cocoa 좌표)와 교집합 면적이 가장 큰 화면. 겹치는 화면이 없으면 main → 첫 화면으로 폴백.
    /// `NSScreen.screens` 접근이 메인 액터 격리이므로 @MainActor.
    @MainActor
    static func bestMatch(forCocoaRect cocoaRect: CGRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in screens {
            let inter = cocoaRect.intersection(screen.frame)
            let area = inter.isNull ? 0 : inter.width * inter.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? main ?? screens.first
    }
}
