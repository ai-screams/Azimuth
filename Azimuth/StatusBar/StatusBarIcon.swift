//
//  StatusBarIcon.swift
//  Azimuth
//
//  메뉴바 아이콘(#179, M2): 왼쪽 반을 채운 창 위에 짧은 호와 북쪽 눈금. 권한이 필요하면 같은 그림 오른쪽 아래에 경고 삼각형을
//  겹친다. template 이미지라 메뉴바의 밝기·강조 상태는 시스템이 칠한다. 좌표는 18pt 상자 기준(아래가 y 0)이고, 디자인 캔버스
//  (.docs 결정 기록의 #179 캔버스) 값을 위아래만 뒤집어 옮겼다.
//

import AppKit

enum StatusBarIcon {
    private static let size = NSSize(width: 18, height: 18)

    static func image(needsPermission: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            draw(needsPermission: needsPermission)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = needsPermission ? "Azimuth — Accessibility access required" : "Azimuth"
        return image
    }

    private static func draw(needsPermission: Bool) {
        NSColor.black.set()
        // 짧은 호: 중심 (9, 7.7), 반지름 7.6, 147.4°에서 32.6°까지 위로.
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: NSPoint(x: 9, y: 7.7),
            radius: 7.6,
            startAngle: 147.4,
            endAngle: 32.6,
            clockwise: true
        )
        arc.lineWidth = 1.2
        arc.lineCapStyle = .round
        arc.stroke()
        // 북쪽 눈금.
        stroke(from: NSPoint(x: 9, y: 16.8), to: NSPoint(x: 9, y: 14.7), width: 1.4)
        // 창 틀과 채운 왼쪽 반.
        let window = NSBezierPath(rect: NSRect(x: 2.8, y: 2.4, width: 12.4, height: 7.6))
        window.lineWidth = 1.2
        window.lineJoinStyle = .round
        window.stroke()
        NSBezierPath(rect: NSRect(x: 3.6, y: 3.2, width: 5.4, height: 6)).fill()
        if needsPermission { drawWarningBadge() }
    }

    /// 경고 삼각형. 뒤 그림을 삼각형보다 조금 크게 지운 뒤 그려 겹친 선이 섞이지 않게 하고, 느낌표는 지워서 낸다.
    private static func drawWarningBadge() {
        guard let context = NSGraphicsContext.current else { return }
        let outer = triangle(NSPoint(x: 13.4, y: 8.4), NSPoint(x: 18.2, y: 0.4), NSPoint(x: 8.6, y: 0.4))
        outer.lineWidth = 1.6
        outer.lineJoinStyle = .round
        context.compositingOperation = .clear
        outer.fill()
        outer.stroke()
        context.compositingOperation = .sourceOver
        triangle(NSPoint(x: 13.4, y: 7.4), NSPoint(x: 17.3, y: 1), NSPoint(x: 9.5, y: 1)).fill()
        context.compositingOperation = .clear
        stroke(from: NSPoint(x: 13.4, y: 5.4), to: NSPoint(x: 13.4, y: 3.4), width: 1.1)
        stroke(from: NSPoint(x: 13.4, y: 2.1), to: NSPoint(x: 13.4, y: 2), width: 1.1)
        context.compositingOperation = .sourceOver
    }

    private static func triangle(_ top: NSPoint, _ right: NSPoint, _ left: NSPoint) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: top)
        path.line(to: right)
        path.line(to: left)
        path.close()
        return path
    }

    private static func stroke(from start: NSPoint, to end: NSPoint, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }
}
