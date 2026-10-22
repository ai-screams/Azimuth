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
    /// 확대 배율. 도형만 커지고 선 굵기·점선 간격은 1배 그대로다(2배에서 윤곽이 무거워 보였다).
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

    /// 그리기만 한다(상태 없음). Canvas 렌더 클로저에서 부르므로 액터에 묶지 않는다.
    private nonisolated static func draw(
        _ glyph: CommandGlyph,
        fill: Color,
        lineScale: CGFloat,
        in context: inout GraphicsContext
    ) {
        drawScreensAndRegion(glyph, fill: fill, lineScale: lineScale, in: &context)
        drawMarks(glyph, color: fill, lineScale: lineScale, in: &context)
    }

    /// 화면 윤곽(늘 글자색), 목표 영역(채움), 원래 크기 점선.
    private nonisolated static func drawScreensAndRegion(
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
        // 점선 간격도 선 굵기처럼 1배로 둔다(배율에 따라 커지지 않게).
        if let ghost = glyph.ghost {
            let dashed = StrokeStyle(lineWidth: 1 * lineScale, dash: [2 * lineScale, 1.5 * lineScale])
            let ghostPath = Path(roundedRect: ghost, cornerRadius: 1.2)
            context.stroke(ghostPath, with: .color(.primary.opacity(0.75)), style: dashed)
        }
    }

    /// 화살표·되돌리기 기호: 직선 획과 원호를 같은 굵기·색으로.
    private nonisolated static func drawMarks(
        _ glyph: CommandGlyph,
        color: Color,
        lineScale: CGFloat,
        in context: inout GraphicsContext
    ) {
        let markStyle = StrokeStyle(lineWidth: 1.5 * lineScale, lineCap: .round, lineJoin: .round)
        for stroke in glyph.strokes {
            var path = Path()
            path.addLines(stroke)
            context.stroke(path, with: .color(color), style: markStyle)
        }
        for arc in glyph.arcs {
            var path = Path()
            // y가 아래로 커지는 좌표에서 clockwise: false는 각도가 커지는 쪽(화면상 시계 방향)으로 그린다.
            path.addArc(
                center: arc.center,
                radius: arc.radius,
                startAngle: .degrees(arc.startDegrees),
                endAngle: .degrees(arc.endDegrees),
                clockwise: false
            )
            context.stroke(path, with: .color(color), style: markStyle)
        }
    }
}
