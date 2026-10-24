//
//  CommandPaletteController.swift
//  Azimuth
//
//  명령 팔레트(#183)를 열고 닫는다. 열 때 대상 앱(`FrontmostAppTracker.targetApplication`)의 앞 창을 한 번만 읽어
//  미리 보기 값을 묶어 두고, 그 창이 있는 화면 위쪽 가운데에 검색 패널을, 고른 명령의 목표 위치에 점선 윤곽을 띄운다.
//  Return이면 패널을 닫고 앱의 실행 경로(`AppDelegate.runCommand`)로 넘긴다.
//
//  패널은 제목 없는 `.nonactivatingPanel`이고 key가 된다: 글자를 받지만 앞의 앱은 그대로라(실기 검사) 대상 앱이 바뀌지
//  않고, 닫은 뒤 포커스를 돌려줄 일도 없다. 제목이 없어야 `updateActivationPolicy`가 Dock 아이콘을 띄우지 않는다.
//

import AppKit
import SwiftUI

@MainActor
final class CommandPaletteController: NSObject, NSWindowDelegate {
    struct Dependencies {
        let tracker: FrontmostAppTracker
        let snapStore: SnapStateStore
        /// 팔레트 켜기·단축키·최근 목록.
        let preferences: PreferencesStore
        /// 명령에 실제로 등록된 단축키(줄의 키캡).
        let shortcut: (WindowCommand) -> HotkeyShortcut?
        /// 팔레트 단축키가 등록에 성공했는지(실패면 아래 줄에 여는 단축키를 보이지 않는다).
        let isRegistered: () -> Bool
        /// 앱의 실행 경로(피드백·실패 사유·연습 창 분기를 같이 탄다).
        let run: (WindowCommand) -> Void
    }

    private let dependencies: Dependencies
    private let model: CommandPaletteModel
    private lazy var panel = makePanel()
    private lazy var outline = PreviewOutlineWindow()
    private var preview: CommandPalettePreviewContext?
    /// 한 번 연 동안 실행했는지. 실행 뒤 닫히기 전에 Return이 한 번 더 와도 두 번 실행하지 않는다.
    private var submitted = false

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let preferences = dependencies.preferences
        model = CommandPaletteModel(
            recent: { preferences.commandPaletteRecent },
            shortcut: dependencies.shortcut,
            paletteShortcut: {
                preferences.commandPaletteEnabled && dependencies.isRegistered() ? preferences
                    .commandPaletteShortcut : nil
            }
        )
        super.init()
        model.onSelectionChange = { [weak self] command in
            self?.showPreview(for: command)
            self?.announce(command)
            // 결과 수가 바뀌었을 수 있다. 화면이 새 결과로 그려진 뒤에 높이를 잰다.
            DispatchQueue.main.async { self?.refit() }
        }
        model.onSubmit = { [weak self] command in self?.submit(command) }
        model.onCancel = { [weak self] in self?.close() }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    /// 설정이 켜져 있으면 팔레트 단축키를 등록한다. 꺼져 있으면 등록하지 않고 true(실패가 아니다).
    /// `beforeOpening`은 누를 때마다 부른다(치트시트가 이 키 누름을 명령 실행처럼 보게).
    func registerHotkey(on service: HotkeyService, beforeOpening: @escaping () -> Void) -> Bool {
        let preferences = dependencies.preferences
        guard preferences.commandPaletteEnabled else { return true }
        let shortcut = preferences.commandPaletteShortcut
        return service.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            beforeOpening()
            self?.toggle()
        }
    }

    /// 팔레트가 열린 채 다른 경로(단축키·팝오버)로 명령이 실행되면 닫는다. 열 때 읽은 창 위치가 낡아 윤곽이 틀린다.
    func dismiss() {
        if panel.isVisible { close() }
    }

    /// 단축키. 열려 있으면 닫는다.
    func toggle() {
        if panel.isVisible {
            close()
        } else {
            show()
        }
    }

    private func show() {
        submitted = false
        // 창을 먼저 읽는다: 띄울 화면이 그 창의 화면이다(사용자 결정). 권한이 없으면 읽지 않고 마우스 화면에 띄운다.
        let window = AccessibilityPermissionService.currentStatus().isTrusted ? readTargetWindow() : nil
        preview = window.flatMap(previewContext)
        model.reset()
        place(on: window.flatMap { screen(forAXFrame: $0.frame.rect) } ?? mouseScreen())
        panel.makeKeyAndOrderFront(nil)
        // 윤곽은 패널 바로 아래에 둔다. 패널이 화면에 올라간 뒤라야 그 순서를 정할 수 있다.
        showPreview(for: model.selected)
    }

    private func close() {
        outline.orderOut(nil)
        panel.orderOut(nil)
        preview = nil
    }

    private func submit(_ command: WindowCommand) {
        guard !submitted else { return }
        submitted = true
        close()
        let preferences = dependencies.preferences
        preferences.commandPaletteRecent = CommandPaletteRecents.touched(
            command.identifier,
            in: preferences.commandPaletteRecent
        )
        dependencies.run(command)
    }

    // MARK: - 대상 창과 미리 보기

    private func readTargetWindow() -> ResolvedWindow? {
        guard let app = dependencies.tracker.targetApplication,
              case let .success(window) = FocusedWindowResolver.resolveFocusedWindow(for: app) else { return nil }
        return window
    }

    private func previewContext(_ window: ResolvedWindow) -> CommandPalettePreviewContext? {
        let frame = window.frame.rect
        guard let workArea = WorkAreaResolver.workArea(forAXWindowFrame: frame) else { return nil }
        var adjacent: [SnapEdge: CGRect] = [:]
        for edge in [SnapEdge.left, .right, .top, .bottom] {
            adjacent[edge] = DisplayResolver.adjacentWorkArea(forAXWindowFrame: frame, edge: edge)
        }
        return CommandPalettePreviewContext(
            current: frame,
            workArea: workArea,
            recorded: dependencies.snapStore.state(for: window.element, pid: window.pid),
            adjacent: adjacent,
            sizeSettable: WindowFrameWriter.settableAnswer(window.element, kAXSizeAttribute)
        )
    }

    private func showPreview(for command: WindowCommand?) {
        guard panel.isVisible, let command, let preview,
              let target = CommandPalettePreview.target(for: command, in: preview)
        else {
            outline.orderOut(nil)
            return
        }
        outline.setFrame(CoordinateSpace.axToCocoa(target), display: true)
        outline.order(.below, relativeTo: panel.windowNumber)
    }

    /// 포커스는 검색줄에 머물러 VoiceOver가 고른 줄을 따라가지 않는다. 고른 명령을 소리로 알린다.
    private func announce(_ command: WindowCommand?) {
        guard panel.isVisible, let command else { return }
        let shortcut = dependencies.shortcut(command).map { ", \($0.displayString)" } ?? ""
        NSAccessibility.post(
            element: panel,
            notification: .announcementRequested,
            userInfo: [
                .announcement: command.displayName + shortcut,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    // MARK: - 패널

    private func screen(forAXFrame frame: CGRect) -> NSScreen? {
        NSScreen.bestMatch(forCocoaRect: CoordinateSpace.axToCocoa(frame))
    }

    private func mouseScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    /// 화면 위쪽 가운데. 위 모서리를 작업영역 높이의 20% 아래에 고정하고, 결과 수에 따라 아래로 늘고 준다.
    private func place(on screen: NSScreen?) {
        guard let visible = screen?.visibleFrame else { return }
        let height = fittingHeight()
        let top = visible.maxY - visible.height * 0.2
        panel.setFrame(
            NSRect(x: visible.midX - CommandPaletteView.width / 2, y: top - height,
                   width: CommandPaletteView.width, height: height),
            display: true
        )
    }

    private func fittingHeight() -> CGFloat {
        guard let hosting = panel.contentViewController as? NSHostingController<CommandPaletteView> else { return 0 }
        return hosting.sizeThatFits(in: CGSize(width: CommandPaletteView.width, height: .greatestFiniteMagnitude))
            .height
    }

    /// 결과 수가 바뀌어 높이가 달라지면 위 모서리를 고정한 채 맞춘다.
    private func refit() {
        guard panel.isVisible else { return }
        let height = fittingHeight()
        var frame = panel.frame
        guard abs(frame.height - height) > 0.5 else { return }
        frame.origin.y = frame.maxY - height
        frame.size.height = height
        panel.setFrame(frame, display: true)
    }

    private func makePanel() -> NSPanel {
        let panel = CommandPalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: CommandPaletteView.width, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        let hosting = NSHostingController(rootView: CommandPaletteView(model: model))
        hosting.sizingOptions = []
        panel.contentViewController = hosting
        return panel
    }

    /// 다른 곳을 눌러 key를 잃으면 닫는다(Spotlight와 같다).
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

/// 제목 없는 패널은 기본적으로 key가 되지 못한다. 글자를 받으려고 연다.
private final class CommandPalettePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

/// 고른 명령이 창을 놓을 자리의 점선 윤곽. 클릭을 받지 않고 Azimuth를 활성화하지 않는다.
private final class PreviewOutlineWindow: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        contentView = NSHostingView(rootView: PreviewOutlineView())
    }
}

/// 브랜드 호박색(#179): 시스템 강조색은 컨트롤 몫이고, 윤곽처럼 Azimuth만의 요소는 앱 아이콘과 같은 색으로 그린다.
private struct PreviewOutlineView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color(.brandAmber), style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .background(Color(.brandAmber).opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}
