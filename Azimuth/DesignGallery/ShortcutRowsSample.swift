//
//  ShortcutRowsSample.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리: 단축키 행 표본(#175·#181): grouped Form 안의 행 — 사용자 지정·녹화 중·꺼짐·선택 상태.
//  값은 모두 로컬 @State라 실제 설정을 바꾸지 않는다.
//

#if DEBUG
    import SwiftUI

    struct ShortcutRowsSample: View {
        var body: some View {
            Form {
                Section("Halves") {
                    ShortcutRowSample(command: .snapThrow(.left), customized: true)
                    ShortcutRowSample(command: .snapThrow(.right), mode: .recording)
                    ShortcutRowSample(command: .snapThrow(.top))
                    ShortcutRowSample(command: .snapThrow(.bottom), enabled: false)
                }
                Section {
                    ShortcutRowSample(command: .maximize, selected: true)
                } header: {
                    Text("Selected row, as in the command palette")
                } footer: {
                    Text("Glyphs stay in the text color in lists; only a selected or active row uses the accent color.")
                }
            }
            .formStyle(.grouped)
            .frame(width: 560, height: 420)
            .scrollDisabled(true)
        }
    }

    private struct ShortcutRowSample: View {
        let command: WindowCommand
        var mode: KeycapsView.Mode = .normal
        var customized = false
        var enabled = true
        var selected = false
        @State private var isOn = true

        init(
            command: WindowCommand,
            mode: KeycapsView.Mode = .normal,
            customized: Bool = false,
            enabled: Bool = true,
            selected: Bool = false
        ) {
            self.command = command
            self.mode = mode
            self.customized = customized
            self.enabled = enabled
            self.selected = selected
            _isOn = State(initialValue: enabled)
        }

        var body: some View {
            HStack(spacing: 10) {
                Toggle(command.displayName, isOn: $isOn).labelsHidden().toggleStyle(.checkbox)
                CommandGlyphView(command: command, emphasized: selected || mode == .recording)
                Text(command.displayName).foregroundStyle(enabled ? .primary : .secondary)
                Spacer()
                if customized {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                        .help("Customized — differs from the preset default.")
                }
                KeycapsView(
                    shortcut: HotkeyPreset.standard.galleryShortcut(for: command),
                    mode: enabled ? mode : .disabled
                )
            }
            .opacity(enabled ? 1 : 0.6)
            // grouped Form에서는 listRowBackground가 적용되지 않아 행 뒤에 직접 깐다.
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .padding(-6)
                }
            }
        }
    }
#endif
