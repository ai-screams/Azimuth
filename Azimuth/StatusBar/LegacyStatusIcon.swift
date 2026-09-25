import AppKit

/// SF Symbol이 없는 macOS 10.13~10.15용 메뉴바 아이콘. 템플릿 이미지라 밝기·강조 상태를 시스템이 칠한다.
/// 권한 있음: 겹친 창 두 개. 권한 없음: 느낌표 삼각형.
enum LegacyStatusIcon {
    static func make(isTrusted: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            if isTrusted {
                let back = NSBezierPath(
                    roundedRect: NSRect(x: 5.5, y: 5.5, width: 11, height: 8),
                    xRadius: 1.5,
                    yRadius: 1.5
                )
                back.lineWidth = 1.2
                back.stroke()
                let front = NSBezierPath(
                    roundedRect: NSRect(x: 1.5, y: 2.5, width: 11, height: 8),
                    xRadius: 1.5,
                    yRadius: 1.5
                )
                NSColor.clear.setFill()
                front.lineWidth = 1.2
                front.stroke()
                NSBezierPath.fill(NSRect(x: 1.5, y: 8.5, width: 11, height: 2))
            } else {
                let triangle = NSBezierPath()
                triangle.move(to: NSPoint(x: rect.midX, y: 14.5))
                triangle.line(to: NSPoint(x: 1.5, y: 1.5))
                triangle.line(to: NSPoint(x: 16.5, y: 1.5))
                triangle.close()
                triangle.lineWidth = 1.2
                triangle.lineJoinStyle = .round
                triangle.stroke()
                NSBezierPath.fill(NSRect(x: rect.midX - 0.75, y: 6, width: 1.5, height: 5))
                NSBezierPath.fill(NSRect(x: rect.midX - 0.75, y: 3.5, width: 1.5, height: 1.5))
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
