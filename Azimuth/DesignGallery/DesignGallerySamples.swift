//
//  DesignGallerySamples.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리의 화면 표본: 단축키 행(#175·#181), General 화면 A안(#175), 팝오버 격자 P1(#178).
//  값은 모두 로컬 @State라 실제 설정을 바꾸지 않는다.
//

#if DEBUG
    import SwiftUI

    // MARK: - 단축키 행

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
        var mode: GalleryKeycaps.Mode = .normal
        var customized = false
        var enabled = true
        var selected = false
        @State private var isOn = true

        init(
            command: WindowCommand,
            mode: GalleryKeycaps.Mode = .normal,
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
                GalleryCommandGlyph(command: command, emphasized: selected || mode == .recording)
                Text(command.displayName).foregroundStyle(enabled ? .primary : .secondary)
                Spacer()
                if customized {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                        .help("Customized — differs from the preset default.")
                }
                GalleryKeycaps(
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

    // MARK: - General 화면 (A안)

    struct GeneralPaneSample: View {
        @State private var launchAtLogin = false
        @State private var hideMenuBarIcon = false
        @State private var sound = true
        @State private var notify = false

        private static let grantedDetail =
            "Accessibility access is enabled. Shortcuts and menu commands can move and resize other app windows."

        var body: some View {
            Form {
                Section("Permissions") {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Azimuth can control other app windows.")
                            Text(Self.grantedDetail).font(.caption).foregroundStyle(.secondary)
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

    // MARK: - 팝오버 격자 (P1)

    struct PopoverGridSample: View {
        @State private var selected: String?
        @State private var useGlass = true

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if #available(macOS 26.0, *) {
                    Toggle("Liquid Glass on the tiles (macOS 26+)", isOn: $useGlass).toggleStyle(.checkbox)
                }
                PopoverGridPanel(selected: $selected, useGlass: useGlass)
            }
        }
    }

    private struct PopoverGridPanel: View {
        @Binding var selected: String?
        let useGlass: Bool

        private var selectedCommand: WindowCommand? {
            WindowCommand.menuCommands.first { $0.displayName == selected }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Azimuth").font(.headline)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text("Accessibility Access: Granted").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(CommandGroup.allCases, id: \.self) { group in
                    Text(group.displayName).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    LazyVGrid(columns: Self.columns, spacing: 4) {
                        ForEach(WindowCommand.menuCommands.filter { $0.group == group }, id: \.displayName) { command in
                            tile(for: command)
                        }
                    }
                }
                Divider()
                statusLine
            }
            .padding(12)
            .frame(width: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        private static let columns = Array(repeating: GridItem(.fixed(34), spacing: 4), count: 8)

        private func tile(for command: WindowCommand) -> some View {
            let name = command.displayName
            return PopoverTile(command: command, isSelected: selected == name, useGlass: useGlass) {
                selected = selected == name ? nil : name
            }
        }

        private var statusLine: some View {
            HStack {
                if let command = selectedCommand {
                    Text("\(command.displayName) — applied to the front window").font(.caption)
                    Spacer()
                    GalleryKeycaps(shortcut: HotkeyPreset.standard.galleryShortcut(for: command))
                } else {
                    Text("Click a command to apply it to the front window.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 26)
        }
    }

    private struct PopoverTile: View {
        let command: WindowCommand
        let isSelected: Bool
        let useGlass: Bool
        let action: () -> Void

        var body: some View {
            // ConcentricRectangle은 바깥 모양을 알려 주는 컨테이너가 없으면 직각이 된다(갤러리 1차에서 확인). 타일은 고정 반경.
            let shape = AnyShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Button(action: action) {
                GalleryCommandGlyph(command: command, emphasized: isSelected)
                    .frame(width: 34, height: 30)
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .help(command.displayName)
            .modifier(TileBackground(shape: shape, isSelected: isSelected, useGlass: useGlass))
        }
    }

    /// 26+에서만 glass를 얹는다. 그 아래와 glass를 끈 경우는 선택 표시만.
    private struct TileBackground: ViewModifier {
        let shape: AnyShape
        let isSelected: Bool
        let useGlass: Bool

        func body(content: Content) -> some View {
            let marked = content
                .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: shape)
                .overlay { shape.stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1) }
            if #available(macOS 26.0, *), useGlass {
                marked.glassEffect(.regular.interactive(), in: shape)
            } else {
                marked
            }
        }
    }
#endif
