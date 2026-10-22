//
//  PopoverGridSample.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리: 메뉴바 팝오버 격자 P1 표본(#178): 그룹별 그림 타일, 26+에서 타일에 Liquid Glass.
//  값은 모두 로컬 @State라 실제 설정을 바꾸지 않는다.
//

#if DEBUG
    import SwiftUI

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
            WindowCommand.menuCommands.first { $0.identifier == selected }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Azimuth").font(.headline)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text(AccessibilityPermissionStatus.granted.menuTitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(CommandGroup.allCases, id: \.self) { group in
                    Text(group.displayName).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    LazyVGrid(columns: Self.columns, spacing: 4) {
                        ForEach(WindowCommand.menuCommands(in: group), id: \.identifier) { command in
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
            let id = command.identifier
            return PopoverTile(command: command, isSelected: selected == id, useGlass: useGlass) {
                selected = selected == id ? nil : id
            }
        }

        private var statusLine: some View {
            HStack {
                if let command = selectedCommand {
                    Text("\(command.displayName) — applied to the front window").font(.caption)
                    Spacer()
                    KeycapsView(shortcut: HotkeyPreset.standard.galleryShortcut(for: command))
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
                CommandGlyphView(command: command, emphasized: isSelected)
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
