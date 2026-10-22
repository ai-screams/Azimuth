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
    /// macOS 14의 협조적 활성화(`activate()`)를 쓴다. 사용자가 다른 앱을 조작 중이면 시스템이 거절할 수 있어,
    /// 메뉴·버튼·재실행처럼 사용자가 방금 Azimuth를 고른 경로에서만 부른다. 전역 단축키(Carbon)에서 부르는
    /// 경로가 생기면(#183 명령 팔레트) 그 경로로 실기 확인한다.
    func bringToFront() {
        activate()
    }
}
