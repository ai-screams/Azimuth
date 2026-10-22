//
//  AboutSettingsView.swift
//  Azimuth
//
//  About 화면: 앱 아이콘·이름·버전·소개, 업데이트 확인, 링크, 저작권. 문구와 링크는 `AboutContent` 한 곳에서 온다.
//  "Check for Updates…"는 Sparkle이 확인을 받을 수 있을 때만 켠다(SwiftUI 버튼은 메뉴 항목처럼 자동 검증되지 않는다).
//

import SwiftUI

struct AboutSettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                        .resizable()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)
                    Text(AboutContent.appName).font(.title.bold())
                    Text(model.versionText).font(.callout).foregroundStyle(.secondary)
                    Text(AboutContent.tagline)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section("Updates") {
                LabeledContent {
                    Button("Check for Updates…", action: model.checkForUpdates)
                        .disabled(!model.canCheckForUpdates)
                } label: {
                    Text("Software updates")
                }
            }
            Section {
                ForEach(AboutContent.links, id: \.url) { link in
                    Link(destination: link.url) {
                        Label(link.title, systemImage: link.symbol)
                            .foregroundStyle(tint(link.tint))
                    }
                }
            } footer: {
                Text(AboutContent.copyright())
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }

    private func tint(_ tint: AboutContent.Tint) -> Color {
        switch tint {
        case .none:
            .accentColor
        case .pink:
            .pink
        case .orange:
            .orange
        }
    }
}
