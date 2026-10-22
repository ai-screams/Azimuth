//
//  ShortcutsSettingsHost.swift
//  Azimuth
//
//  Shortcuts 화면은 아직 AppKit(`ShortcutsPaneViewController`)이다. SwiftUI로 옮기는 일은 #175의 두 번째 단계에서
//  한다. 그때까지 사이드바 화면 안에 그대로 끼운다(녹화·충돌·등록 실패 동작을 바꾸지 않는다).
//

import SwiftUI

struct ShortcutsSettingsHost: NSViewControllerRepresentable {
    let dependencies: SettingsDependencies

    func makeNSViewController(context: Context) -> ShortcutsPaneViewController {
        ShortcutsPaneViewController(
            preferencesStore: dependencies.preferencesStore,
            onHotkeysChanged: dependencies.onHotkeysChanged,
            registrationFailures: dependencies.registrationFailures,
            setHotkeysSuspended: dependencies.setHotkeysSuspended
        )
    }

    func updateNSViewController(_ controller: ShortcutsPaneViewController, context: Context) {}
}
