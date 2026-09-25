//
//  NSApplication+BringToFront.swift
//  Azimuth
//
//  메뉴바 전용(.accessory) 앱을 사용자 조작 직후 전면으로 가져오는 호출을 한 곳에 모은다
//  (About 창·Settings 창·첫 실행 팝오버 공용).
//

import AppKit

extension NSApplication {
    /// 앱을 활성화해 이어서 띄울 창·팝오버가 전면에 오게 한다.
    /// 14+ 전용 `activate()` 대신 이 API를 쓰는 이유는 macOS 13 지원이다. SDK상 to-be-deprecated라
    /// 경고는 없고, 실제로 폐기되면 이 한 곳에서만 `if #available` 분기로 바꾼다.
    func bringToFront() {
        activate(ignoringOtherApps: true)
    }
}
