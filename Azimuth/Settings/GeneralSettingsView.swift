//
//  GeneralSettingsView.swift
//  Azimuth
//
//  General 화면: 권한 · 시작 · 피드백 · 치트시트(#182) · 연습(#175 A안). 켜고 끄는 설정은 스위치. 값과 동작은 `SettingsModel`이 가진다.
//

import SwiftUI

struct GeneralSettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section("Permissions") {
                PermissionRow(model: model)
            }
            Section {
                Toggle("Launch Azimuth at login", isOn: binding(\.launchAtLogin, model.setLaunchAtLogin))
                if model.launchNeedsApproval {
                    LabeledContent {
                        Button("Open Login Items Settings…", action: model.openLoginItemsSettings)
                    } label: {
                        Text("Login item is registered but needs approval in System Settings > General > Login Items.")
                            .foregroundStyle(.orange)
                    }
                }
                Toggle("Hide menu bar icon", isOn: binding(\.menuBarIconHidden, model.setMenuBarIconHidden))
            } header: {
                Text("Startup")
            } footer: {
                Text("When hidden, open Azimuth again from Finder or Spotlight to reopen this window.")
            }
            Section {
                Toggle("Play a sound when a command can't run", isOn: binding(\.soundFeedback, model.setSoundFeedback))
                Toggle("Notify when a command fails", isOn: binding(\.notifyOnFailure, model.setNotifyOnFailure))
                if model.showsNotifyHint {
                    Text("Enable notifications for Azimuth in System Settings > Notifications, then try again.")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Feedback")
            }
            Section {
                Toggle(
                    "Show shortcuts while holding the modifier keys",
                    isOn: binding(\.cheatSheetEnabled, model.setCheatSheetEnabled)
                )
                Picker("Show after", selection: Binding(
                    get: { model.cheatSheetDelay },
                    set: model.setCheatSheetDelay
                )) {
                    ForEach(CheatSheetDelay.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .disabled(!model.cheatSheetEnabled)
            } header: {
                Text("Cheat Sheet")
            } footer: {
                Text(
                    "Hold the modifier keys of a shortcut, such as ⌃⌥, to see which key does what. "
                        + "It closes when you let go."
                )
            }
            Section("Practice") {
                LabeledContent("Try the main shortcuts on a sample window") {
                    Button("Start…", action: model.showPracticeGuide)
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .navigationTitle("General")
    }

    private func binding(_ value: KeyPath<SettingsModel, Bool>, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { model[keyPath: value] }, set: set)
    }
}

private struct PermissionRow: View {
    let model: SettingsModel

    var body: some View {
        let status = model.permission
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(status.isTrusted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(status.settingsStatusText)
                Text(status.settingsDetailText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if !status.isTrusted {
                Button("Open Accessibility Settings…", action: model.requestAccessibility)
            } else if model.permissionJustGranted {
                // 권한을 막 준 순간이 연습하기 가장 좋은 때다. 자동으로 열지 않고 사용자가 누르게 해야
                // 연습 창이 확실히 앞에 와 단축키를 받는다(#176).
                Button("Try the Shortcuts…", action: model.showPracticeGuide)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
