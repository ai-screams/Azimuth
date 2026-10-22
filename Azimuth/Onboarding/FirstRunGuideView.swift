//
//  FirstRunGuideView.swift
//  Azimuth
//
//  첫 실행 안내 팝오버의 내용(#176). 시스템 권한 대화상자처럼 보이지 않게 앱 아이콘 머리 + 안내 줄로 짜고,
//  시스템 색만 써서 라이트·다크를 따라간다. 권한이 없으면 기본 버튼이 "Open Settings…"가 되어 설정 창
//  General(권한)로 이어진다. 팝오버를 띄우고 닫는 일은 `FirstRunGuidePresenter`가 한다.
//

import os
import SwiftUI

struct FirstRunGuideView: View {
    let launchService: LaunchAtLoginService
    let needsPermission: Bool
    let onOpenSettings: () -> Void
    let onDone: () -> Void

    @State private var launchAtLogin: Bool

    init(
        launchService: LaunchAtLoginService,
        needsPermission: Bool,
        onOpenSettings: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.launchService = launchService
        self.needsPermission = needsPermission
        self.onOpenSettings = onOpenSettings
        self.onDone = onDone
        _launchAtLogin = State(initialValue: launchService.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true) // 뜻은 제목이 전한다
                Text("Azimuth lives in your menu bar")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 9) {
                GuideRow(symbol: "macwindow.on.rectangle", text: "Click the menu bar icon for commands and settings.")
                GuideRow(symbol: "keyboard", text: "Move and resize windows from anywhere with global shortcuts.")
                if needsPermission {
                    GuideRow(
                        symbol: "exclamationmark.triangle.fill",
                        text: "Accessibility permission is required before Azimuth can control windows.",
                        tint: .orange
                    )
                }
            }
            Toggle("Launch Azimuth at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                .toggleStyle(.checkbox)
            Button(action: primaryAction) {
                Text(needsPermission ? "Open Settings…" : "Got it").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .frame(width: 300)
    }

    /// 설정의 같은 스위치와 같은 정공법 경로(SMAppService). 등록이 실패하면 체크를 되돌려
    /// "켜진 것처럼 보이는데 등록 안 됨"을 막는다. 승인 필요 상태 안내는 설정 창이 맡는다.
    private func setLaunchAtLogin(_ isOn: Bool) {
        guard isOn else {
            launchService.disable()
            launchAtLogin = false
            return
        }
        do {
            try launchService.enable()
            launchAtLogin = true
        } catch {
            launchAtLogin = false
            NSSound.beep()
            Log.app
                .error("First-run guide failed to register login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func primaryAction() {
        if needsPermission { onOpenSettings() }
        onDone()
    }
}

private struct GuideRow: View {
    let symbol: String
    let text: String
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .frame(width: 18)
                .accessibilityHidden(true) // 뜻은 옆 글이 전한다
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
