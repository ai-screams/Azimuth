//
//  CommandPaletteView.swift
//  Azimuth
//
//  명령 팔레트(#183, K1) 내용: 검색줄, 결과 줄(그림 · 이름 · 키캡), 아래 안내 줄. 고른 줄은 옅은 강조 배경과 강조색 그림.
//  검색줄은 AppKit `NSTextField`다 — 필드 편집기의 명령(moveUp: 등)으로 ↑↓·Return·Esc를 받고, 한글 조합 중 Return도
//  확정된 글자로 한 번만 온다(실기 검사, .docs 결정 기록). SwiftUI `onKeyPress`는 쓰지 않는다.
//

import AppKit
import Observation
import SwiftUI

@Observable
final class CommandPaletteModel {
    @ObservationIgnored private let recent: () -> [String]
    @ObservationIgnored let shortcut: (WindowCommand) -> HotkeyShortcut?
    @ObservationIgnored let paletteShortcut: () -> HotkeyShortcut?
    /// 고른 명령이 바뀜(미리 보기를 다시 그린다).
    @ObservationIgnored var onSelectionChange: (WindowCommand?) -> Void = { _ in }
    @ObservationIgnored var onSubmit: (WindowCommand) -> Void = { _ in }
    @ObservationIgnored var onCancel: () -> Void = {}

    private(set) var query = ""
    private(set) var results: [WindowCommand] = []
    private(set) var selection = 0
    /// 열 때마다 바뀐다. 검색줄이 이 값으로 비우고 포커스를 다시 잡는다.
    private(set) var session = 0

    init(
        recent: @escaping () -> [String],
        shortcut: @escaping (WindowCommand) -> HotkeyShortcut?,
        paletteShortcut: @escaping () -> HotkeyShortcut?
    ) {
        self.recent = recent
        self.shortcut = shortcut
        self.paletteShortcut = paletteShortcut
    }

    var selected: WindowCommand? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    func reset() {
        session += 1
        setQuery("")
    }

    func setQuery(_ text: String) {
        query = text
        results = CommandPaletteSearch.results(query: text, recent: recent())
        selection = 0
        onSelectionChange(selected)
    }

    func move(_ delta: Int) {
        selection = CommandPaletteSelection.moved(selection, by: delta, count: results.count)
        onSelectionChange(selected)
    }

    func submit(at index: Int? = nil) {
        if let index { selection = index }
        guard let selected else {
            NSSound.beep()
            return
        }
        onSubmit(selected)
    }

    func cancel() {
        onCancel()
    }
}

struct CommandPaletteView: View {
    let model: CommandPaletteModel

    static let width: CGFloat = 560
    static let rowHeight: CGFloat = 40
    static let visibleRows = 8
    static let cornerRadius: CGFloat = 14
    private static let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                CommandPaletteField(model: model)
                    .frame(height: 28)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            if model.results.isEmpty {
                Text("No commands match.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(width: Self.width)
        .background(.regularMaterial, in: Self.shape)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.identifier) { index, command in
                        CommandPaletteRow(
                            command: command,
                            shortcut: model.shortcut(command),
                            isSelected: index == model.selection
                        )
                        .id(command.identifier)
                        .onTapGesture { model.submit(at: index) }
                    }
                }
                .padding(6)
            }
            .frame(height: CGFloat(min(model.results.count, Self.visibleRows)) * (Self.rowHeight + 2) + 10)
            .onChange(of: model.selection) { _, _ in
                if let selected = model.selected { proxy.scrollTo(selected.identifier) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            hint("↩", "Apply")
            hint("↑↓", "Select")
            hint("esc", "Close")
            Spacer()
            if let shortcut = model.paletteShortcut() {
                HStack(spacing: 6) {
                    Text("Open with").foregroundStyle(.secondary)
                    KeycapsView(shortcut: shortcut)
                }
            }
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key).fontWeight(.semibold)
            Text(label).foregroundStyle(.secondary)
        }
    }
}

private struct CommandPaletteRow: View {
    let command: WindowCommand
    let shortcut: HotkeyShortcut?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            CommandGlyphView(command: command, emphasized: isSelected)
            Text(command.displayName)
            Spacer(minLength: 8)
            if let shortcut {
                KeycapsView(shortcut: shortcut)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: CommandPaletteView.rowHeight)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
            in: AdaptiveShapes.inner(outer: CommandPaletteView.cornerRadius, inset: 6) // 목록 안쪽 여백 6
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityText: String {
        guard let shortcut else { return command.displayName }
        return "\(command.displayName), \(shortcut.displayString)"
    }
}

/// 검색줄. 필드 편집기가 보내는 명령을 받아 모델로 넘긴다. 처음 그릴 때와 열 때마다 포커스를 잡는다.
private struct CommandPaletteField: NSViewRepresentable {
    let model: CommandPaletteModel

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "Search commands"
        field.font = .systemFont(ofSize: 20)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.usesSingleLineMode = true
        field.delegate = context.coordinator
        field.setAccessibilityLabel("Search commands")
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        guard context.coordinator.session != model.session else { return }
        context.coordinator.session = model.session
        field.stringValue = model.query
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let model: CommandPaletteModel
        var session = -1

        init(model: CommandPaletteModel) {
            self.model = model
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            model.setQuery(field.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                model.move(-1)
            case #selector(NSResponder.moveDown(_:)):
                model.move(1)
            case #selector(NSResponder.insertNewline(_:)):
                model.submit()
            case #selector(NSResponder.cancelOperation(_:)):
                model.cancel()
            default:
                return false
            }
            return true
        }
    }
}
