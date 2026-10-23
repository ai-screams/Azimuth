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
    private let soundEnabled: () -> Bool
    private var window: NSWindow?

    /// `shortcut`: 명령에 지금 실제로 등록된 단축키(꺼졌거나 등록에 실패했으면 nil).
    /// `soundEnabled`: 소리 피드백 설정. 일반 명령 경로처럼 꺼져 있으면 경고음을 내지 않는다.
    init(shortcut: @escaping (WindowCommand) -> HotkeyShortcut?, soundEnabled: @escaping () -> Bool) {
        model = PracticeModel(shortcut: shortcut)
        self.soundEnabled = soundEnabled
    }

    /// 처음부터 다시 연다(다시 보기도 같은 길).
    func show() {
        model.restart()
        let window = window ?? makeWindow()
        self.window = window
        window.setContentSize(Self.size)
        window.centerOnMouseScreen()
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
            if soundEnabled() { NSSound.beep() } // 되돌릴 기록이 없거나 연습 창에서 하지 않는 명령
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
        let hosting = NSHostingController(rootView: view)
        // 연습 창의 frame이 곧 연습 대상이다. 내용이 바뀔 때 창이 내용 크기로 돌아가면 방금 옮긴 자리가 어긋난다.
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "Practice Shortcuts"
        window.isReleasedWhenClosed = false // 다시 보기에서 같은 창을 쓴다
        window.contentMinSize = NSSize(width: 360, height: 300)
        return window
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
