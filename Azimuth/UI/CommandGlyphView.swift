//
//  CommandGlyphView.swift
//  Azimuth
//
//  명령 그림(#181)을 그리는 SwiftUI 뷰. 도형은 `WindowCommand.glyph`(Commands/CommandGlyph)가 정한다.
//  색 규칙: 목록에서는 글자색(단색), 선택·활성 행에서만 시스템 강조색(`emphasized`).
//

import SwiftUI

struct CommandGlyphView: View {
    let command: WindowCommand
    var emphasized = false
    /// 확대 배율. 도형만 커지고 선 굵기는 1배 그대로다(2배에서 윤곽이 무거워 보였다).
    var scale: CGFloat = 1

    var body: some View {
        let glyph = command.glyph
        let fill = emphasized ? Color.accentColor : Color.primary
        Canvas { context, _ in
            context.scaleBy(x: scale, y: scale)
            Self.draw(glyph, fill: fill, lineScale: 1 / scale, in: &context)
        }
        .frame(width: CommandGlyph.box.width * scale, height: CommandGlyph.box.height * scale)
        .accessibilityElement()
        .accessibilityLabel(command.displayName)
    }

    private static func draw(
        _ glyph: CommandGlyph,
        fill: Color,
        lineScale: CGFloat,
        in context: inout GraphicsContext
    ) {
        let line = StrokeStyle(lineWidth: 1.4 * lineScale, lineCap: .round, lineJoin: .round)
        context.stroke(Path(roundedRect: glyph.screen, cornerRadius: 2.5), with: .color(.primary), style: line)
        if let second = glyph.secondScreen {
            context.stroke(Path(roundedRect: second, cornerRadius: 2), with: .color(.primary), style: line)
        }
        if let region = glyph.region {
            context.fill(Path(roundedRect: region, cornerRadius: 1.2), with: .color(fill.opacity(0.9)))
        }
        // 원래 크기(점선)는 채운 부분 위에 그린다. 아래에 두면 실제 크기에서 가려져 반쪽 그림과 구분되지 않았다.
        if let ghost = glyph.ghost {
            let dashed = StrokeStyle(lineWidth: 1 * lineScale, dash: [2, 1.5])
            let ghostPath = Path(roundedRect: ghost, cornerRadius: 1.2)
            context.stroke(ghostPath, with: .color(.primary.opacity(0.75)), style: dashed)
        }
        let arrowStyle = StrokeStyle(lineWidth: 1.5 * lineScale, lineCap: .round, lineJoin: .round)
        for stroke in glyph.strokes {
            var path = Path()
            path.addLines(stroke)
            context.stroke(path, with: .color(fill), style: arrowStyle)
        }
        if glyph.isUndo {
            context.stroke(undoPath, with: .color(fill), style: arrowStyle)
        }
    }

    /// 위쪽 가로선 → 오른쪽 반원 → 아래 가로선, 왼쪽 위에 화살촉.
    private static let undoPath: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 8))
        path.addLine(to: CGPoint(x: 16, y: 8))
        path.addArc(
            center: CGPoint(x: 16, y: 11.5),
            radius: 3.5,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 10.5, y: 15))
        path.move(to: CGPoint(x: 12.6, y: 5.4))
        path.addLine(to: CGPoint(x: 10, y: 8))
        path.addLine(to: CGPoint(x: 12.6, y: 10.6))
        return path
    }()
}
