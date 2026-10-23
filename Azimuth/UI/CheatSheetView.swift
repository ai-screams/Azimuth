//
//  CheatSheetView.swift
//  Azimuth
//
//  단축키 치트시트(#182, C1 키보드 지도). 누르고 있는 수정키 층의 명령을 자판 위 키에 그림과 짧은 이름으로
//  올리고, 쓰지 않는 키는 흐리게 그린다. 위에는 누른 수정키와 층 이름, "Release to close".
//  어떤 키에 어떤 명령이 오는지는 `CheatSheetLayer`가 정한다.
//

import SwiftUI

struct CheatSheetView: View {
    let layer: CheatSheetLayer

    /// 숫자 줄(14키)이 약 700pt에 들어가는 크기. 58pt로 그렸더니 900pt가 넘어 갤러리 창에서 잘렸다.
    static let keySize = CGSize(width: 44, height: 60)
    private static let spacing: CGFloat = 4
    private static let widths = CheatSheetKeyboard.widths(unit: keySize.width, spacing: spacing)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(alignment: .leading, spacing: Self.spacing) {
                ForEach(Array(CheatSheetKeyboard.rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: Self.spacing) {
                        ForEach(Array(row.enumerated()), id: \.offset) { keyIndex, key in
                            KeyCell(
                                keyCode: key.keyCode,
                                command: key.keyCode.flatMap { layer.mapped[$0] },
                                width: Self.widths[rowIndex][keyIndex]
                            )
                        }
                    }
                }
            }
            if !layer.others.isEmpty {
                othersStrip
            }
        }
        .padding(18)
        .fixedSize()
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(Array(CarbonModifier.glyphs(for: layer.modifiers)), id: \.self) { glyph in
                    Keycap(label: String(glyph))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CarbonModifier.glyphs(for: layer.modifiers))
            Text(layer.title).font(.headline)
            Spacer(minLength: 24)
            Text("Release to close").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var othersStrip: some View {
        HStack(spacing: 14) {
            Text("Other keys").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(layer.others.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    CommandGlyphView(command: item.command)
                    Text(item.command.displayName).font(.caption)
                    KeycapsView(shortcut: item.shortcut)
                }
            }
        }
    }
}

private struct KeyCell: View {
    let keyCode: UInt32?
    let command: WindowCommand?
    let width: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        VStack(spacing: 2) {
            HStack {
                Text(keyCode.map(HotkeyShortcut.keyLabel(for:)) ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(command == nil ? .tertiary : .secondary)
                Spacer(minLength: 0)
            }
            if let command {
                CommandGlyphView(command: command)
                Text(command.displayName)
                    .font(.system(size: 8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(4)
        .frame(width: width, height: CheatSheetView.keySize.height)
        .background(command == nil ? Color.primary.opacity(0.03) : Color.primary.opacity(0.08), in: shape)
        .overlay { shape.stroke(Color.primary.opacity(command == nil ? 0.08 : 0.2), lineWidth: 0.5) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHidden(command == nil)
    }

    private var accessibilityText: String {
        guard let command, let keyCode else { return "" }
        return "\(HotkeyShortcut.keyLabel(for: keyCode)): \(command.displayName)"
    }
}
