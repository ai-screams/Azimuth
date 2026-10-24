//
//  ShortcutsSettingsView.swift
//  Azimuth
//
//  Shortcuts 화면: 프리셋, 전체 초기화, 검색(창 툴바), 그룹별 단축키 줄. 줄은 체크(켜기) · 명령 그림 · 이름(겹침·시스템 사용
//  표시) · 사용자 지정 점 · 키캡 · 되돌리기(↺). 키캡을 누르면 그 자리에서 녹화한다(`ShortcutKeyCatcher`).
//  그룹은 처음에 모두 접혀 있고, 검색하면 걸린 그룹이 저절로 펼쳐진다.
//

import SwiftUI

struct ShortcutsSettingsView: View {
    let model: ShortcutsSettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Keymap preset", selection: Binding(get: { model.preset }, set: model.setPreset)) {
                    ForEach(HotkeyPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                LabeledContent("Custom shortcuts") {
                    Button("Reset All", action: model.resetAll)
                }
            } footer: {
                Text("Click a shortcut to record a new key combo. Esc cancels.")
            }
            Section {
                CommandPaletteShortcutRow(
                    row: model.paletteRow,
                    isRecording: model.recording == CommandPaletteShortcut.identifier,
                    model: model
                )
            } footer: {
                Text("Opens a search panel for every command, with a preview of where the window goes.")
            }
            let sections = model.sections
            if sections.isEmpty {
                Section {
                    Text("No shortcuts match your search.").foregroundStyle(.secondary)
                }
            }
            ForEach(sections) { section in
                Section {
                    GroupHeaderRow(section: section, isSearching: model.isSearching, model: model)
                    ForEach(section.rows) { row in
                        ShortcutRow(row: row, isRecording: model.recording == row.id, model: model)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shortcuts")
        .searchable(
            text: Binding(get: { model.query }, set: model.setQuery),
            placement: .toolbar,
            prompt: "Filter shortcuts"
        )
        .onAppear(perform: model.appear)
        .onDisappear(perform: model.cancelRecording)
    }
}

/// 그룹 머리 줄: 펼침 삼각형(보기만 바꾼다)과 그룹 켜기 체크(전역 단축키 등록을 바꾼다). 뜻이 달라 접근성 이름도 다르다.
private struct GroupHeaderRow: View {
    let section: ShortcutsSettingsModel.GroupSection
    let isSearching: Bool
    let model: ShortcutsSettingsModel

    var body: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { model.toggleExpanded(section.group) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(section.isExpanded ? 90 : 0))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            // 검색 중에는 펼침이 검색 결과를 따른다. 눌러도 바뀌지 않으므로 끈다.
            .disabled(isSearching)
            .accessibilityLabel("\(section.group.displayName) shortcuts")
            .accessibilityValue(section.isExpanded ? "Expanded" : "Collapsed")
            Toggle(isOn: Binding(get: { section.isEnabled }, set: { model.setGroupEnabled(section.group, $0) })) {
                Text(section.group.displayName).fontWeight(.semibold)
            }
            .toggleStyle(.checkbox)
            Spacer()
        }
    }
}

private struct ShortcutRow: View {
    let row: ShortcutsSettingsModel.Row
    let isRecording: Bool
    let model: ShortcutsSettingsModel

    var body: some View {
        ShortcutRowContent(
            name: row.command.displayName,
            help: row.command.helpText,
            shortcut: row.shortcut,
            display: row.display,
            isRecording: isRecording,
            actions: ShortcutRowActions(
                setEnabled: { model.setCommandEnabled(row.command, $0) },
                reset: { model.reset(row.command) },
                toggleRecording: { model.toggleRecording(row.command) },
                finishRecording: { model.finishRecording(row.command, with: $0) }
            )
        ) {
            CommandGlyphView(command: row.command, emphasized: isRecording)
        }
    }
}

/// 팔레트 단축키 줄(#183): 명령 줄과 같은 모양에 그림 대신 돋보기.
private struct CommandPaletteShortcutRow: View {
    let row: ShortcutsSettingsModel.PaletteRow
    let isRecording: Bool
    let model: ShortcutsSettingsModel

    var body: some View {
        ShortcutRowContent(
            name: "Command Palette",
            help: "Search every command by name and see where the window goes before applying it.",
            shortcut: row.shortcut,
            display: row.display,
            isRecording: isRecording,
            actions: ShortcutRowActions(
                setEnabled: model.setCommandPaletteEnabled,
                reset: model.resetCommandPalette,
                toggleRecording: model.toggleCommandPaletteRecording,
                finishRecording: model.finishCommandPaletteRecording
            )
        ) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isRecording ? Color.accentColor : Color.primary)
                .frame(width: 28, height: 20)
        }
    }
}

private struct ShortcutRowActions {
    let setEnabled: (Bool) -> Void
    let reset: () -> Void
    let toggleRecording: () -> Void
    let finishRecording: (HotkeyShortcut?) -> Void
}

/// 단축키 줄 하나: 체크(켜기) · 그림 · 이름(배지) · 사용자 지정 점 · 키캡 · 되돌리기. 명령 줄과 팔레트 줄이 같이 쓴다.
private struct ShortcutRowContent<Glyph: View>: View {
    let name: String
    let help: String
    let shortcut: HotkeyShortcut?
    let display: ShortcutRowDisplay
    let isRecording: Bool
    let actions: ShortcutRowActions
    @ViewBuilder let glyph: Glyph

    var body: some View {
        HStack(spacing: 8) {
            Toggle(name, isOn: Binding(get: { display.checkboxOn }, set: actions.setEnabled))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!display.checkboxEnabled)
                .accessibilityLabel("Enable \(name)")
            glyph
                .opacity(display.isDimmed ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .foregroundStyle(display.isDimmed ? .secondary : .primary)
                    .lineLimit(1)
                    .help(help) // 무엇을 하는 명령인지 hover로 설명한다
                BadgeText(badge: display.badge)
            }
            Spacer(minLength: 8)
            if display.showsModifiedDot {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .help("Customized — differs from the preset default.")
                    .accessibilityLabel("Customized")
            }
            recorder
            Button {
                actions.reset()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .help("Reset to the preset shortcut")
            .accessibilityLabel("Reset \(name) shortcut")
            // 자리는 늘 차지해 키캡 열이 줄마다 같은 위치에 오게 한다.
            .opacity(display.resetEnabled ? 1 : 0)
            .disabled(!display.resetEnabled)
            .accessibilityHidden(!display.resetEnabled)
        }
    }

    private var recorder: some View {
        Button {
            actions.toggleRecording()
        } label: {
            KeycapsView(
                shortcut: shortcut,
                mode: isRecording ? .recording : (display.recorderEnabled ? .normal : .disabled)
            )
        }
        .buttonStyle(.plain)
        .disabled(!display.recorderEnabled)
        .accessibilityLabel("Shortcut for \(name)")
        .accessibilityValue(isRecording ? "Recording" : (shortcut?.displayString ?? "None"))
        .help(isRecording ? "Type a key combo. Esc cancels." : "Click to record a new shortcut")
        .background {
            if isRecording {
                ShortcutKeyCatcher(onFinish: actions.finishRecording)
            }
        }
    }
}

private struct BadgeText: View {
    let badge: ShortcutRowBadge

    var body: some View {
        switch badge {
        case .none:
            EmptyView()
        case .duplicate:
            Label("Duplicate", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .help("Duplicate — this shortcut won't trigger this command.")
        case .systemOccupied:
            Label("In use by system", systemImage: "exclamationmark.octagon.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .help("In use by system — this shortcut won't trigger this command.")
        }
    }
}
