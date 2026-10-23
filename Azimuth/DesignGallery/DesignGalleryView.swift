//
//  DesignGalleryView.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리: HTML 목업에서 고른 안을 실제 SwiftUI로 그려 질감·크기·모서리를 실기로 본다.
//  표본 상태(사용자 지정, 녹화 중, 꺼짐)는 모양 확인용 가짜 값이고 설정에 쓰지 않는다.
//

#if DEBUG
    import Carbon.HIToolbox
    import SwiftUI

    struct DesignGalleryView: View {
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    GallerySection(title: "Command glyphs (#181)") { GlyphCatalog() }
                    GallerySection(title: "Keycaps (#181)") { KeycapStates() }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 760, minHeight: 600)
        }
    }

    private struct GallerySection<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.title3.weight(.semibold))
                content
            }
        }
    }

    // MARK: - #181 명령 그림

    private struct GlyphCatalog: View {
        @State private var emphasizeAll = false

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show every glyph in the accent color (selected state)", isOn: $emphasizeAll)
                    .toggleStyle(.checkbox)
                ForEach(CommandGroup.allCases, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.displayName).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading) {
                            ForEach(WindowCommand.menuCommands(in: group), id: \.identifier) { command in
                                GlyphCell(command: command, emphasized: emphasizeAll)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct GlyphCell: View {
        let command: WindowCommand
        let emphasized: Bool

        var body: some View {
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 8) {
                    CommandGlyphView(command: command, emphasized: emphasized)
                    CommandGlyphView(command: command, emphasized: emphasized, scale: 2)
                }
                Text(command.displayName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(6)
        }
    }

    // MARK: - #181 키캡

    private struct KeycapStates: View {
        private let sample = HotkeyPreset.standard.galleryShortcut(for: .maximizeGaps)
        /// ⌃⌥F12: 키 라벨이 여러 글자여도 캡 하나로 그려지는지 본다.
        private let longKey = HotkeyShortcut(keyCode: UInt32(kVK_F12), modifiers: UInt32(controlKey | optionKey))

        var body: some View {
            HStack(spacing: 18) {
                labeled("Normal") { KeycapsView(shortcut: sample) }
                labeled("Long key label") { KeycapsView(shortcut: longKey) }
                labeled("Recording") { KeycapsView(shortcut: sample, mode: .recording) }
                labeled("No shortcut") { KeycapsView(shortcut: nil) }
                labeled("Disabled") { KeycapsView(shortcut: sample, mode: .disabled) }
            }
        }

        private func labeled(_ text: String, @ViewBuilder _ content: () -> some View) -> some View {
            VStack(spacing: 6) {
                content()
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
#endif
