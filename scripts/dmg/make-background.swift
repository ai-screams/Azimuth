// DMG 설치 창 배경(#179)을 그린다: background.png(540×380)와 background@2x.png.
// 실행: swift scripts/dmg/make-background.swift scripts/dmg
// 좌표는 release.sh의 create-dmg 배치와 같다(창 540×380, 앱 아이콘 중심 140,200, Applications 400,200, 아이콘 100).
// 구성: 구름 낀 파란 하늘, 앱 아이콘을 둘러싼 항공 방위계(N·E·W, 북쪽은 호박색), Applications로 가는 점선 항로와 비행기.
// 남색 앱 아이콘(Azimuth/AppIcon.icon)이 밝은 하늘 위에서 도드라지게 했다.

import AppKit
import CoreImage

let size = NSSize(width: 540, height: 380)
func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

let skyTop = rgb(0x3F7FCC)
let skyBottom = rgb(0xB8DDF7)
let navy = rgb(0x1E3A5F)
let amber = rgb(0xE8912A)
let appCenter = NSPoint(x: 140, y: 200)

func point(_ center: NSPoint, _ radius: CGFloat, _ degrees: CGFloat) -> NSPoint {
    // 위쪽이 0°, 시계 방향(뒤집힌 좌표: y가 아래로).
    let radians = (degrees - 90) * .pi / 180
    return NSPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians))
}

func segment(_ from: NSPoint, _ to: NSPoint, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: from)
    path.line(to: to)
    path.lineWidth = width
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

func drawText(_ text: String, size: CGFloat, weight: NSFont.Weight, kern: CGFloat, color: NSColor, center: NSPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: kern
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let bounds = string.size()
    // 자간이 마지막 글자 뒤에도 붙으므로 그만큼 빼고 가운데에 둔다.
    string.draw(at: NSPoint(x: center.x - (bounds.width - kern) / 2, y: center.y - bounds.height / 2))
}

/// 구름: 겹친 원 몇 개를 흐리게 번진 흰색으로. (가운데 x, 밑선 y, 크기 배율, 불투명도)
let clouds: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (70, 96, 1.0, 0.85), (300, 262, 0.7, 0.55), (470, 120, 1.15, 0.9), (250, 330, 1.3, 0.75), (520, 320, 0.9, 0.7), (30, 345, 0.9, 0.65)
]

func cloudLayer(scale: CGFloat) -> CGImage? {
    let width = Int(size.width * scale), height = Int(size.height * scale)
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.scaleBy(x: scale, y: scale)
    for (x, baseY, k, alpha) in clouds {
        // 뒤집지 않은 좌표라 위아래를 바꿔 넣는다.
        let y = size.height - baseY
        context.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
        for (dx, dy, r) in [(-34.0, 8.0, 18.0), (-12, 18, 25), (14, 14, 21), (34, 6, 15), (0, 4, 22)] as [(CGFloat, CGFloat, CGFloat)] {
            context.fillEllipse(in: CGRect(x: x + dx * k - r * k, y: y + dy * k - r * k, width: 2 * r * k, height: 2 * r * k))
        }
        context.fill(CGRect(x: x - 48 * k, y: y - 6 * k, width: 96 * k, height: 12 * k))
    }
    guard let sharp = context.makeImage() else { return nil }
    let blurred = CIImage(cgImage: sharp).clampedToExtent()
        .applyingGaussianBlur(sigma: 5 * Double(scale)).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    return CIContext().createCGImage(blurred, from: blurred.extent)
}

func draw(scale: CGFloat) {
    // 하늘: 위가 짙은 파랑, 아래로 갈수록 밝게.
    NSGradient(starting: skyTop, ending: skyBottom)?.draw(in: NSRect(origin: .zero, size: size), angle: 90)
    if let clouds = cloudLayer(scale: scale), let context = NSGraphicsContext.current?.cgContext {
        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(clouds, in: CGRect(origin: .zero, size: size))
        context.restoreGState()
    }

    // 항공 방위계: 반투명 흰 판, 남색 10° 눈금, 30°마다 긴 눈금, N·E·W.
    let dialRadius: CGFloat = 86
    let plate = NSBezierPath(ovalIn: NSRect(
        x: appCenter.x - dialRadius, y: appCenter.y - dialRadius, width: 2 * dialRadius, height: 2 * dialRadius
    ))
    NSColor.white.withAlphaComponent(0.35).setFill()
    plate.fill()
    plate.lineWidth = 2
    navy.withAlphaComponent(0.7).setStroke()
    plate.stroke()
    for degrees in stride(from: 0, to: 360, by: 10) {
        let major = degrees % 30 == 0
        segment(
            point(appCenter, dialRadius - 2, CGFloat(degrees)),
            point(appCenter, dialRadius - (major ? 11 : 7), CGFloat(degrees)),
            width: major ? 1.8 : 1,
            color: navy.withAlphaComponent(major ? 0.8 : 0.5)
        )
    }
    // S 자리(아이콘 아래 y 266)에는 Finder가 앱 이름을 쓰므로 비워 둔다.
    for (letter, degrees) in [("N", 0), ("E", 90), ("W", 270)] as [(String, CGFloat)] {
        let color = letter == "N" ? amber : navy
        drawText(letter, size: 11, weight: .bold, kern: 0, color: color, center: point(appCenter, dialRadius - 20, degrees))
    }
    // 북쪽 표시(바깥 삼각형).
    let north = NSBezierPath()
    north.move(to: NSPoint(x: appCenter.x, y: appCenter.y - dialRadius - 4))
    north.line(to: NSPoint(x: appCenter.x + 7, y: appCenter.y - dialRadius - 15))
    north.line(to: NSPoint(x: appCenter.x - 7, y: appCenter.y - dialRadius - 15))
    north.close()
    amber.setFill()
    north.fill()

    // 항로: 방위계 바깥(x 236)에서 Applications 아이콘 왼쪽(x 344)까지 위로 볼록한 점선, 끝에 비행기.
    let arcCenter = NSPoint(x: 270, y: 296)
    let radius: CGFloat = 110
    let start: CGFloat = -29.4, end: CGFloat = 22 // 위쪽 0° 기준. 끝은 비행기 자리를 남긴다
    let route = NSBezierPath()
    route.appendArc(withCenter: arcCenter, radius: radius, startAngle: start - 90, endAngle: end - 90, clockwise: false)
    route.lineWidth = 2.5
    route.lineCapStyle = .round
    route.setLineDash([2, 7], count: 2, phase: 0)
    navy.withAlphaComponent(0.75).setStroke()
    route.stroke()
    let planeAt = point(arcCenter, radius, 30)
    if let plane = NSImage(systemSymbolName: "airplane", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 22, weight: .semibold)),
        let context = NSGraphicsContext.current?.cgContext {
        let tinted = NSImage(size: plane.size, flipped: false) { rect in
            plane.draw(in: rect)
            amber.set()
            rect.fill(using: .sourceIn)
            return true
        }
        context.saveGState()
        context.translateBy(x: planeAt.x, y: planeAt.y)
        // 뒤집힌 좌표에 그리면 기호가 왼쪽을 향한다(실측). 반 바퀴 더 돌려 항로의 접선(오른쪽 아래로 30°)에 맞춘다.
        context.rotate(by: (30 + 180) * .pi / 180)
        tinted.draw(in: NSRect(x: -plane.size.width / 2, y: -plane.size.height / 2, width: plane.size.width, height: plane.size.height),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        context.restoreGState()
    }

    drawText("AZIMUTH", size: 22, weight: .semibold, kern: 8, color: .white, center: NSPoint(x: 270, y: 52))
    drawText(
        "Drag Azimuth onto Applications to install", size: 12, weight: .medium, kern: 0,
        color: navy.withAlphaComponent(0.85), center: NSPoint(x: 270, y: 340)
    )
}

func render(scale: CGFloat, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    // 뒤집힌 좌표(위가 y 0): create-dmg 배치 좌표를 그대로 쓴다.
    let context = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context!.cgContext, flipped: true)
    let cg = NSGraphicsContext.current!.cgContext
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)
    draw(scale: scale)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: url)
}

let folder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try render(scale: 1, to: folder.appendingPathComponent("background.png"))
try render(scale: 2, to: folder.appendingPathComponent("background@2x.png"))
