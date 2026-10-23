//
//  StatusPopoverView.swift
//  Azimuth
//
//  메뉴바 팝오버(#178) 내용: 위에 권한 상태, 가운데 34개 명령을 그룹별 그림 타일(8열)로,
//  아래에 누른 명령의 이름과 키캡, 마지막 실패 사유, 설정·업데이트·종료.
//  권한이 없으면 격자를 흐리게 하고 누를 수 없게 한다. glass는 #179에서 다룬다.
//

import SwiftUI

struct StatusPopoverView: View {
    @Bindable var model: StatusPopoverModel
    @FocusState private var gridFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            grid
            Divider()
            appliedLine
            if let failure = model.lastFailure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .onExitCommand(perform: model.close)
        .onAppear { gridFocused = model.isTrusted }
    }

    @ViewBuilder private var header: some View {
        HStack {
            Text("Azimuth").font(.headline)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(model.isTrusted ? Color.green : Color.orange).frame(width: 7, height: 7)
                    .accessibilityHidden(true) // 뜻은 옆 글이 전한다
                Text(model.isTrusted ? AccessibilityPermissionStatus.granted.menuTitle
                    : AccessibilityPermissionStatus.required.menuTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        if !model.isTrusted {
            Text("Azimuth needs Accessibility access before it can move other apps' windows.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Accessibility Settings…", action: model.requestAccessibility)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(CommandGroup.allCases, id: \.self) { group in
                Text(group.displayName).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                // Lazy 격자는 이상 높이가 정해지지 않아 팝오버가 처음 잰 크기가 틀리고 메뉴 막대 위로 밀려 올라갔다.
                // 줄은 커서와 같은 `PopoverGridLayout`에서 받는다.
                Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 4) {
                    ForEach(Self.rows(in: group), id: \.lowerBound) { row in
                        GridRow {
                            ForEach(row, id: \.self) { index in
                                tile(for: PopoverGridLayout.commands[index], index: index)
                            }
                        }
                    }
                }
            }
        }
        .disabled(!model.isTrusted)
        .opacity(model.isTrusted ? 1 : 0.4)
        // 화살표로 커서를 옮기고 Return·Space로 적용한다. 타일 단추는 마우스와 VoiceOver가 쓴다.
        .focusable(model.isTrusted)
        .focused($gridFocused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { move(.left) }
        .onKeyPress(.rightArrow) { move(.right) }
        .onKeyPress(.upArrow) { move(.up) }
        .onKeyPress(.downArrow) { move(.down) }
        .onKeyPress(.return) { applyCursor() }
        .onKeyPress(.space) { applyCursor() }
    }

    private static func rows(in group: CommandGroup) -> [Range<Int>] {
        PopoverGridLayout.standard.rows.filter { PopoverGridLayout.commands[$0.lowerBound].group == group }
    }

    private func move(_ move: PopoverGridLayout.Move) -> KeyPress.Result {
        model.moveCursor(move)
        return .handled
    }

    private func applyCursor() -> KeyPress.Result {
        guard model.cursor != nil else { return .ignored }
        model.applyCursor()
        return .handled
    }

    private func tile(for command: WindowCommand, index: Int) -> some View {
        PopoverTile(
            command: command,
            isApplied: model.applied == command,
            hasCursor: gridFocused && model.cursor == index
        ) {
            model.cursor = index
            model.apply(command)
        }
    }

    private var appliedLine: some View {
        HStack {
            if let command = model.applied {
                Text(command.displayName).font(.caption)
                Spacer()
                KeycapsView(shortcut: model.shortcut(for: command))
            } else {
                Text("Click a command to apply it to the front window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 26)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            FooterButton(title: "Open Settings…", shortcut: "⌘,", action: model.openSettings)
                .keyboardShortcut(",")
            FooterButton(title: "Check for Updates…", shortcut: nil, action: model.checkForUpdates)
                .disabled(!model.canCheckForUpdates)
            FooterButton(title: "Quit Azimuth", shortcut: "⌘Q", action: model.quit)
                .keyboardShortcut("q")
        }
    }
}

private struct PopoverTile: View {
    let command: WindowCommand
    let isApplied: Bool
    let hasCursor: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Button(action: action) {
            CommandGlyphView(command: command, emphasized: isApplied)
                .frame(width: 34, height: 30)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(command.displayName)
        .background(background, in: shape)
        .overlay { shape.stroke(isApplied ? Color.accentColor : .clear, lineWidth: 1) }
        .overlay { shape.inset(by: -2).stroke(hasCursor ? Color.accentColor : .clear, lineWidth: 2) }
        .onHover { isHovered = $0 }
        .accessibilityLabel(command.displayName)
        .accessibilityAddTraits(isApplied ? .isSelected : [])
    }

    /// 누른 타일은 강조색, 마우스가 올라간 타일은 옅은 글자색. 권한이 없어 꺼졌으면 호버를 보이지 않는다.
    private var background: Color {
        if isApplied { return Color.accentColor.opacity(0.12) }
        return isHovered && isEnabled ? Color.primary.opacity(0.08) : .clear
    }
}

/// 메뉴 항목처럼 보이는 글자 단추. 오른쪽에 단축키를 흐리게 적고, 마우스가 올라가면 메뉴처럼
/// 강조색 바탕에 흰 글자로 바뀐다.
private struct FooterButton: View {
    let title: String
    let shortcut: String?
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let highlighted = isHovered && isEnabled
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut).foregroundStyle(highlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                }
            }
            .foregroundStyle(highlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                highlighted ? Color.accentColor : .clear,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -6) // 글자는 위 내용과 같은 선에 두고 바탕만 양옆으로 넓힌다
        .onHover { isHovered = $0 }
    }
}
