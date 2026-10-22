//
//  PracticeWindowController.swift
//  Azimuth
//
//  연습 창(#176): Azimuth 자신의 창 하나로 Left 1/2 → Maximize → Undo를 직접 해 본다. 창 안 내용이 곧 안내다
//  (`PracticeView`). 연습 창이 앞에 있을 때 받은 단축키는 AX 경로(자기 창은 대상이 아니다) 대신 여기서
//  같은 기하로 연습 창을 옮긴다. 단계와 판정은 `PracticeSession`(순수)이 한다.
//

import Cocoa
import SwiftUI

@MainActor
final class PracticeWindowController {
    private static let size = NSSize(width: 520, height: 360)

    private let model: PracticeModel
    private var window: NSWindow?

    /// `shortcut`: 명령에 지금 묶인 단축키(프리셋과 사용자 지정, 꺼진 명령이면 nil).
    init(shortcut: @escaping (WindowCommand) -> HotkeyShortcut?) {
        model = PracticeModel(shortcut: shortcut)
    }

    /// 처음부터 다시 연다(다시 보기도 같은 길).
    func show() {
        model.restart()
        let window = window ?? makeWindow()
        self.window = window
        window.setContentSize(Self.size)
        centerOnActiveScreen(window)
        NSApp.bringToFront()
        window.makeKeyAndOrderFront(nil)
    }

    /// 단축키 하나. 연습 창이 앞에 있으면 연습 창을 옮기고 true(명령 실행기로 보내지 않는다).
    func handle(_ command: WindowCommand) -> Bool {
        guard let window, window.isVisible, window.isKeyWindow, NSApp.isActive else { return false }
        guard let screen = window.screen ?? NSScreen.main,
              let workArea = CoordinateSpace.axWorkArea(of: screen)
        else { return true }
        let current = CoordinateSpace.cocoaToAX(window.frame)
        guard let target = model.session.target(for: command, current: current, workArea: workArea) else {
            NSSound.beep() // 되돌릴 기록이 없거나 연습 창에서 하지 않는 명령
            return true
        }
        window.setFrame(CoordinateSpace.axToCocoa(target), display: true, animate: true)
        let actual = CoordinateSpace.cocoaToAX(window.frame)
        _ = model.session.didMove(command, target: target, actual: actual)
        return true
    }

    private func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let view = PracticeView(model: model, onClose: { [weak self] in self?.close() })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "Practice Shortcuts"
        window.isReleasedWhenClosed = false // 다시 보기에서 같은 창을 쓴다
        window.contentMinSize = NSSize(width: 360, height: 300)
        return window
    }

    private func centerOnActiveScreen(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }
}

@Observable
final class PracticeModel {
    var session = PracticeSession()
    @ObservationIgnored private let shortcutLookup: (WindowCommand) -> HotkeyShortcut?

    init(shortcut: @escaping (WindowCommand) -> HotkeyShortcut?) {
        shortcutLookup = shortcut
    }

    func restart() {
        session = PracticeSession()
    }

    func shortcut(for command: WindowCommand) -> HotkeyShortcut? {
        shortcutLookup(command)
    }
}
