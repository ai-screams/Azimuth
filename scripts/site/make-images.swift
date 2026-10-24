// 사이트 이미지(#180)를 앱 아이콘(Azimuth/AppIcon.icon)으로 다시 만든다: docs/assets의 favicon.png(32), apple-touch-icon.png(180),
// og-image.png(1200×630, 공유 미리 보기). 아이콘은 Icon Composer의 ictool로 그리고, og-image 배경은 DMG 창(scripts/dmg)과 같은
// 구름 낀 하늘이다. 남색 아이콘이 밝은 하늘 위에서 도드라진다.
// 실행: swift scripts/site/make-images.swift <ictool 경로> Azimuth/AppIcon.icon docs/assets

import AppKit
import CoreImage

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: make-images.swift <ictool> <AppIcon.icon> <out dir>\n".utf8))
    exit(2)
}
let ictool = arguments[1], iconDocument = arguments[2]
let out = URL(fileURLWithPath: arguments[3])
let work = FileManager.default.temporaryDirectory.appendingPathComponent("azimuth-site-images")
try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

/// ictool로 아이콘 한 장(Default, macOS)을 그린다.
func renderIcon(size: Int) throws -> NSImage {
    let file = work.appendingPathComponent("icon-\(size).png")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ictool)
    process.arguments = [iconDocument, "--export-image", "--output-file", file.path, "--platform", "macOS",
                         "--rendition", "Default", "--width", "\(size)", "--height", "\(size)", "--scale", "1"]
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0, let image = NSImage(contentsOf: file) else { throw CocoaError(.fileReadUnknown) }
    return image
}

func writePNG(size: NSSize, to url: URL, draw: () -> Void) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: url)
}

func rgb(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// 흐리게 번진 흰 구름. (가운데 x, 밑선 y(아래가 0), 크기 배율, 불투명도)
func clouds(size: NSSize, _ list: [(CGFloat, CGFloat, CGFloat, CGFloat)]) -> CGImage? {
    guard let context = CGContext(
        data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    for (x, y, k, alpha) in list {
        context.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
        for (dx, dy, r) in [(-34.0, 8.0, 18.0), (-12, 18, 25), (14, 14, 21), (34, 6, 15), (0, 4, 22)] as [(CGFloat, CGFloat, CGFloat)] {
            context.fillEllipse(in: CGRect(x: x + dx * k - r * k, y: y + dy * k - r * k, width: 2 * r * k, height: 2 * r * k))
        }
        context.fill(CGRect(x: x - 48 * k, y: y - 6 * k, width: 96 * k, height: 12 * k))
    }
    guard let sharp = context.makeImage() else { return nil }
    let blurred = CIImage(cgImage: sharp).clampedToExtent().applyingGaussianBlur(sigma: 9)
        .cropped(to: CGRect(origin: .zero, size: size))
    return CIContext().createCGImage(blurred, from: blurred.extent)
}

try writePNG(size: NSSize(width: 32, height: 32), to: out.appendingPathComponent("favicon.png")) {
    try? renderIcon(size: 32).draw(in: NSRect(x: 0, y: 0, width: 32, height: 32))
}
// iOS는 apple-touch-icon의 투명한 곳을 검게 채우고 모서리는 스스로 둥글린다. 아이콘 바탕색으로 꽉 채운 정사각형에 그린다.
try writePNG(size: NSSize(width: 180, height: 180), to: out.appendingPathComponent("apple-touch-icon.png")) {
    rgb(0x1E3A5F).setFill()
    NSRect(x: 0, y: 0, width: 180, height: 180).fill()
    try? renderIcon(size: 196).draw(in: NSRect(x: -8, y: -8, width: 196, height: 196))
}

let og = NSSize(width: 1200, height: 630)
let icon = try renderIcon(size: 1024)
try writePNG(size: og, to: out.appendingPathComponent("og-image.png")) {
    NSGradient(starting: rgb(0x3F7FCC), ending: rgb(0xB8DDF7))?.draw(in: NSRect(origin: .zero, size: og), angle: -90)
    let list: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (120, 520, 1.6, 0.8), (1080, 560, 1.3, 0.7), (980, 90, 2.0, 0.85), (180, 70, 1.8, 0.75), (640, 600, 1.1, 0.5)
    ]
    if let layer = clouds(size: og, list) { NSGraphicsContext.current?.cgContext.draw(layer, in: CGRect(origin: .zero, size: og)) }
    icon.draw(in: NSRect(x: 130, y: 135, width: 360, height: 360))
    let navy = rgb(0x1E3A5F)
    let title = NSAttributedString(string: "Azimuth", attributes: [
        .font: NSFont.systemFont(ofSize: 96, weight: .bold), .foregroundColor: navy
    ])
    title.draw(at: NSPoint(x: 540, y: 320))
    let tagline = NSAttributedString(string: "Keyboard-driven window manager\nfor macOS", attributes: [
        .font: NSFont.systemFont(ofSize: 38, weight: .medium), .foregroundColor: navy.withAlphaComponent(0.85)
    ])
    tagline.draw(at: NSPoint(x: 544, y: 200))
}
print("wrote favicon.png, apple-touch-icon.png, og-image.png")
