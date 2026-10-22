//
//  KeycapsView.swift
//  Azimuth
//
//  단축키 표시(#181, Keycaps 안): 수정키와 키마다 캡 하나. 라벨은 `HotkeyShortcut.keycapLabels`에서 온다.
//

import SwiftUI

struct KeycapsView: View {
    enum Mode {
        case normal
        /// 녹화 중: "Type shortcut…"과 강조색 테두리.
        case recording
        /// 단축키 없음: "—".
        case empty
        /// 꺼진 명령: 흐리게.
        case disabled
    }

    let shortcut: HotkeyShortcut?
    var mode: Mode = .normal

    var body: some View {
        HStack(spacing: 3) {
            switch mode {
            case .recording:
                Text("Type shortcut…").font(.system(size: 12)).padding(.horizontal, 6)
            case .empty:
                Text("—").foregroundStyle(.secondary).padding(.horizontal, 6)
            case .normal, .disabled:
                ForEach(Array((shortcut?.keycapLabels ?? []).enumerated()), id: \.offset) { _, label in
                    Keycap(label: label)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch mode {
        case .recording:
            "Recording shortcut"
        case .empty:
            "No shortcut"
        case .normal, .disabled:
            shortcut?.displayString ?? "No shortcut"
        }
    }
}

private struct Keycap: View {
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
