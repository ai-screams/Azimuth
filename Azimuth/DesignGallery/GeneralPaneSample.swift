//
//  GeneralPaneSample.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리: General 화면 A안 표본(#175): 권한·시작·피드백, 켜고 끄는 설정은 스위치.
//  값은 모두 로컬 @State라 실제 설정을 바꾸지 않는다.
//

#if DEBUG
    import SwiftUI

    struct GeneralPaneSample: View {
        @State private var launchAtLogin = false
        @State private var hideMenuBarIcon = false
        @State private var sound = true
        @State private var notify = false

        var body: some View {
            Form {
                Section("Permissions") {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AccessibilityPermissionStatus.granted.settingsStatusText)
                            Text(AccessibilityPermissionStatus.granted.settingsDetailText)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                Section {
                    Toggle("Launch Azimuth at login", isOn: $launchAtLogin)
                    Toggle("Hide menu bar icon", isOn: $hideMenuBarIcon)
                } header: {
                    Text("Startup")
                } footer: {
                    Text("When hidden, open Azimuth again from Finder or Spotlight to reopen this window.")
                }
                Section("Feedback") {
                    Toggle("Play a sound when a command can't run", isOn: $sound)
                    Toggle("Notify when a command fails", isOn: $notify)
                }
            }
            .formStyle(.grouped)
            .toggleStyle(.switch)
            .frame(width: 560, height: 420)
            .scrollDisabled(true)
        }
    }
#endif
