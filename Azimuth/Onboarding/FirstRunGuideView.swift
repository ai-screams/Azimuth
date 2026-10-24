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
    let onTryShortcuts: () -> Void
    let onDone: () -> Void

    @State private var launchAtLogin: Bool

    init(
        launchService: LaunchAtLoginService,
        needsPermission: Bool,
        onOpenSettings: @escaping () -> Void,
        onTryShortcuts: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.launchService = launchService
        self.needsPermission = needsPermission
        self.onOpenSettings = onOpenSettings
        self.onTryShortcuts = onTryShortcuts
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
                GuideRow(
                    image: Image(nsImage: StatusBarIcon.image(needsPermission: false)),
                    text: "Click the menu bar icon for commands and settings."
                )
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
            buttons
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

    /// 권한이 없으면 설정(권한 줄)로 보낸다. 권한이 생기면 그 줄에 연습 창 버튼이 나온다(`SettingsWindowController`).
    /// 권한이 있으면 바로 연습 창으로 갈 수 있다(#176).
    @ViewBuilder private var buttons: some View {
        if needsPermission {
            Button {
                onOpenSettings()
                onDone()
            } label: {
                Text("Open Settings…").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        } else {
            HStack {
                Button(action: onDone) {
                    Text("Not Now").frame(maxWidth: .infinity)
                }
                Button {
                    onTryShortcuts()
                    onDone()
                } label: {
                    Text("Try the Shortcuts").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
    }
}

private struct GuideRow: View {
    /// 그림. 메뉴바 아이콘 줄은 실제 메뉴바 아이콘(#179)을, 나머지는 SF Symbol을 쓴다.
    let image: Image
    let text: String
    var tint: Color = .secondary

    init(symbol: String, text: String, tint: Color = .secondary) {
        self.init(image: Image(systemName: symbol), text: text, tint: tint)
    }

    init(image: Image, text: String, tint: Color = .secondary) {
        self.image = image
        self.text = text
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            image
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
