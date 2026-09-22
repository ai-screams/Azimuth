//
//  NSScreen+BestMatch.swift
//  Azimuth
//
//  Cocoa 좌표 사각형과 가장 많이 겹치는 화면 선택. WorkAreaResolver·DisplayResolver가
//  각자 복사해 쓰던 동일 로직을 한 곳으로 모았다. 선택 규칙(면적 → 중심 포함 → displayID)은
//  순수 계층 `DisplayGeometry.bestMatchIndex`에 있고 여기서는 NSScreen → 값 매핑과 폴백만 한다.
//

import AppKit

extension NSScreen {
    /// `cocoaRect`(Cocoa 좌표)와 교집합 면적이 가장 큰 화면. 겹치는 화면이 없으면 main → 첫 화면으로 폴백.
    /// `NSScreen.screens` 접근이 메인 액터 격리이므로 @MainActor.
    @MainActor
    static func bestMatch(forCocoaRect cocoaRect: CGRect) -> NSScreen? {
        // 한 번만 바인딩한다. `screens`는 접근할 때마다 현재 디스플레이 목록을 다시 만드는 계산
        // 프로퍼티라, 매핑 때와 첨자 때 길이가 다르면 범위를 넘는다(DisplayResolver 와 같은 패턴).
        let screens = NSScreen.screens
        let candidates = screens.map { ScreenCandidate(frame: $0.frame, displayID: $0.displayID) }
        guard let index = DisplayGeometry.bestMatchIndex(window: cocoaRect, candidates: candidates) else {
            return main ?? screens.first
        }
        return screens[index]
    }

    /// CoreGraphics display ID. 열거 순서와 무관한 안정적 tie-break 키(없으면 최대값으로 폴백).
    private var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? .max
    }
}
