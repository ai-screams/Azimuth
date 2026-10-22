//
//  SettingsRootView.swift
//  Azimuth
//
//  설정 창의 뼈대: 시스템 설정과 같은 사이드바 + 화면(#175). 각 화면은 grouped `Form`이다.
//  권한이 없으면 사이드바 General 옆에 경고 점을 붙인다.
//

import SwiftUI

struct SettingsRootView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        NavigationSplitView {
            List(SettingsModel.Pane.allCases, selection: $model.selection) { pane in
                SidebarRow(pane: pane, needsAttention: pane == .general && !model.permission.isTrusted)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail(for: model.selection ?? .general)
        }
    }

    @ViewBuilder
    private func detail(for pane: SettingsModel.Pane) -> some View {
        switch pane {
        case .general:
            GeneralSettingsView(model: model)
        case .shortcuts:
            ShortcutsSettingsHost(dependencies: model.dependencies)
                .navigationTitle(pane.title)
        case .advanced:
            AdvancedSettingsView(model: model)
        case .about:
            AboutSettingsView(model: model)
        }
    }
}

private struct SidebarRow: View {
    let pane: SettingsModel.Pane
    let needsAttention: Bool

    var body: some View {
        HStack {
            Label(pane.title, systemImage: pane.symbol)
            Spacer()
            if needsAttention {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Needs attention")
            }
        }
    }
}
