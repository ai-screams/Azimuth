//
//  NSWindow+CenterOnMouseScreen.swift
//  Azimuth
//
//  Azimuth 자신의 창(설정 창, 연습 창)을 띄울 때의 배치를 한 곳에 모은다.
//

import AppKit

extension NSWindow {
    /// 멀티모니터에서 창이 다른 디스플레이에 묻히지 않게, 마우스가 있는 화면 중앙에 배치한다.
    func centerOnMouseScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = frame.size
        setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        ))
    }
}
