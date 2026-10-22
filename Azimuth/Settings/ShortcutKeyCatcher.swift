//
//  ShortcutKeyCatcher.swift
//  Azimuth
//
//  녹화 중인 키캡 위에 놓는 보이지 않는 AppKit 뷰. 놓이면 first responder가 되어 다음 키 조합 하나를 받는다.
//  SwiftUI `onKeyPress`는 Carbon 등록에 필요한 키 코드를 주지 않아 쓰지 않는다. 받은 키의 판단은
//  `ShortcutCapturePolicy`(순수)가 하고, 여기서는 이벤트를 넘기고 결과를 알린다.
//
//  끝을 알리는 길은 `onFinish` 하나이고 한 번만 부른다: 기록, Esc, Tab, 다른 곳을 눌러 포커스를 잃을 때,
//  뷰가 창에서 빠질 때(줄이 사라짐). 그래야 녹화 중 멈춘 전역 단축키가 늘 다시 켜진다.
//

import SwiftUI

struct ShortcutKeyCatcher: NSViewRepresentable {
    /// 기록한 조합, 또는 취소면 nil.
    let onFinish: (HotkeyShortcut?) -> Void

    func makeNSView(context: Context) -> ShortcutKeyCatcherView {
        let view = ShortcutKeyCatcherView()
        view.onFinish = onFinish
        return view
    }

    func updateNSView(_ view: ShortcutKeyCatcherView, context: Context) {
        view.onFinish = onFinish
    }
}

final class ShortcutKeyCatcherView: NSView {
    var onFinish: ((HotkeyShortcut?) -> Void)?
    private var finished = false

    override var acceptsFirstResponder: Bool {
        !finished
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        // SwiftUI가 뷰를 붙이는 도중에는 first responder를 바꾸지 못할 수 있어 다음 차례에 잡는다.
        // 잡지 못하면 키가 오지 않으므로 바로 취소한다(녹화가 멈춘 채 남지 않게).
        DispatchQueue.main.async { [weak self] in
            guard let self, !finished else { return }
            if window?.makeFirstResponder(self) != true { finish(nil) }
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { finish(nil) }
        super.viewWillMove(toWindow: newWindow)
    }

    override func keyDown(with event: NSEvent) {
        let outcome = ShortcutCapturePolicy.decide(
            keyCode: event.keyCode,
            carbonModifiers: CarbonModifier.mask(from: event.modifierFlags),
            isRepeat: event.isARepeat
        )
        switch outcome {
        case .cancel:
            finish(nil)
        case .cancelAndMoveFocus:
            finish(nil)
            window?.selectKeyView(following: self)
        case .ignore:
            break
        case .reject:
            NSSound.beep()
        case let .capture(shortcut):
            finish(shortcut)
        }
    }

    /// 녹화 중에는 ⌘ 조합도 받는다. 키 창의 뷰 계층이 메인 메뉴보다 먼저 받으므로 여기서 소비해야
    /// ⌘Q·⌘W 같은 메뉴가 가져가지 않는다.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !finished, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        finish(nil)
        return super.resignFirstResponder()
    }

    private func finish(_ shortcut: HotkeyShortcut?) {
        guard !finished else { return }
        finished = true
        onFinish?(shortcut)
    }
}
