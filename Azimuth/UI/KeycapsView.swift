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
        /// 꺼진 명령: 흐리게.
        case disabled
    }

    /// nil이면 "—"(단축키 없음). 빈 상자와 낭독("No shortcut")이 어긋나지 않게 모드가 아니라 값에서 정한다.
    let shortcut: HotkeyShortcut?
    var mode: Mode = .normal

    var body: some View {
        HStack(spacing: 3) {
            if mode == .recording {
                Text("Type shortcut…").font(.system(size: 12)).padding(.horizontal, 6)
            } else if let shortcut {
                ForEach(Array(shortcut.keycapLabels.enumerated()), id: \.offset) { _, label in
                    Keycap(label: label)
                }
            } else {
                Text("—").foregroundStyle(.secondary).padding(.horizontal, 6)
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
        if mode == .recording { return "Recording shortcut" }
        return shortcut?.displayString ?? "No shortcut"
    }
}

/// 키캡 하나. 치트시트 머리의 수정키처럼 키 하나씩 따로 그릴 때도 쓴다.
struct Keycap: View {
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
