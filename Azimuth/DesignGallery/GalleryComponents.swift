//
//  GalleryComponents.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리 전용 부품: 명령 그림(Outline), 키캡, 카드 모양.
//  #181·#175에서 정한 디자인을 실제 SwiftUI로 그려 macOS에서 질감·크기를 확인하는 용도다.
//

#if DEBUG
    import SwiftUI

    /// 명령 그림. 목록에서는 글자색(단색), 선택·활성 행에서만 강조색(`emphasized`).
    struct GalleryCommandGlyph: View {
        let command: WindowCommand
        var emphasized = false
        var scale: CGFloat = 1

        var body: some View {
            let geometry = GalleryGlyphGeometry.of(command)
            let fillColor = emphasized ? Color.accentColor : Color.primary
            Canvas { context, _ in
                // 확대해도 선 굵기는 그대로 둔다(도형만 커지고 획은 1배 굵기).
                context.scaleBy(x: scale, y: scale)
                draw(geometry, fill: fillColor, lineScale: 1 / scale, in: &context)
            }
            .frame(width: GalleryGlyphGeometry.box.width * scale, height: GalleryGlyphGeometry.box.height * scale)
            .accessibilityElement()
            .accessibilityLabel(command.displayName)
        }

        private func draw(
            _ geometry: GalleryGlyphGeometry,
            fill: Color,
            lineScale: CGFloat,
            in context: inout GraphicsContext
        ) {
            let line = StrokeStyle(lineWidth: 1.4 * lineScale, lineCap: .round, lineJoin: .round)
            context.stroke(Path(roundedRect: geometry.screen, cornerRadius: 2.5), with: .color(.primary), style: line)
            if let second = geometry.secondScreen {
                context.stroke(Path(roundedRect: second, cornerRadius: 2), with: .color(.primary), style: line)
            }
            if let region = geometry.region {
                context.fill(Path(roundedRect: region, cornerRadius: 1.2), with: .color(fill.opacity(0.9)))
            }
            // 원래 크기(점선)는 채운 부분 위에 그린다. 아래에 두면 실제 크기에서 가려져 반쪽 그림과 구분되지 않았다.
            if let ghost = geometry.ghost {
                let dashed = StrokeStyle(lineWidth: 1 * lineScale, dash: [2, 1.5])
                let ghostPath = Path(roundedRect: ghost, cornerRadius: 1.2)
                context.stroke(ghostPath, with: .color(.primary.opacity(0.75)), style: dashed)
            }
            let arrowStyle = StrokeStyle(lineWidth: 1.5 * lineScale, lineCap: .round, lineJoin: .round)
            for stroke in geometry.strokes {
                var path = Path()
                path.addLines(stroke)
                context.stroke(path, with: .color(fill), style: arrowStyle)
            }
            if geometry.isUndo {
                context.stroke(Self.undoPath, with: .color(fill), style: arrowStyle)
            }
        }

        /// 위쪽 가로선 → 오른쪽 반원 → 아래 가로선, 왼쪽 위에 화살촉. HTML 목업의 `M10 8 H16 A3.5…`와 같다.
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

    /// 단축키 표시(Keycaps 안): 수정키와 키마다 캡 하나.
    /// 표시 문자열을 글자 단위로 쪼개지 않고 수정자 마스크와 키 라벨에서 만든다("F12", "Space"도 캡 하나).
    struct GalleryKeycaps: View {
        enum Mode {
            case normal
            case recording
            case empty
            case disabled
        }

        let shortcut: HotkeyShortcut?
        var mode: Mode = .normal

        private var keys: [String] {
            guard let shortcut else { return [] }
            let modifiers = CarbonModifier.glyphs(for: shortcut.modifiers).map(String.init)
            return modifiers + [HotkeyShortcut.keyLabel(for: shortcut.keyCode)]
        }

        var body: some View {
            HStack(spacing: 3) {
                switch mode {
                case .recording:
                    Text("Type shortcut…").font(.system(size: 12)).padding(.horizontal, 6)
                case .empty:
                    Text("—").foregroundStyle(.secondary).padding(.horizontal, 6)
                case .normal, .disabled:
                    ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                        GalleryKeycap(label: key)
                    }
                }
            }
            .padding(3)
            .frame(minHeight: 26)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(mode == .recording ? Color.accentColor : .clear, lineWidth: 1)
            }
            .opacity(mode == .disabled ? 0.4 : 1)
        }
    }

    private struct GalleryKeycap: View {
        let label: String

        var body: some View {
            Text(label)
                .font(.system(size: 12))
                .padding(.horizontal, 4)
                .frame(minWidth: 20, minHeight: 20)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                }
        }
    }

    extension HotkeyPreset {
        /// 갤러리 표본용: 이 프리셋에서 `command`의 기본 단축키.
        func galleryShortcut(for command: WindowCommand) -> HotkeyShortcut? {
            guard let binding = bindings.first(where: { $0.command == command }) else { return nil }
            return HotkeyShortcut(keyCode: binding.keyCode, modifiers: binding.modifiers)
        }
    }
#endif
