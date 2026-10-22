//
//  GeneralSettingsView.swift
//  Azimuth
//
//  General 화면: 권한 · 시작 · 피드백(#175 A안). 켜고 끄는 설정은 스위치. 값과 동작은 `SettingsModel`이 가진다.
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
            }
        }
    }
}
