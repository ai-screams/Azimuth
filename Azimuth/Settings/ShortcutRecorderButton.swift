//
//  ShortcutRecorderButton.swift
//  Azimuth
//
//  클릭하면 녹화 모드로 들어가 다음 키 조합 한 번을 캡처하는 버튼.
//  Esc=취소, 수정자 없는 단일 키는 거부(전역 단축키엔 수정자가 필요).
//

import Carbon.HIToolbox
import Cocoa

@MainActor
final class ShortcutRecorderButton: NSButton {
    var onCapture: ((HotkeyShortcut) -> Void)?
    /// 녹화 시작(true)/종료(false)를 알린다. 녹화 중 전역 핫키를 일시 정지하는 데 쓴다.
    var onRecordingStateChanged: ((Bool) -> Void)?

    private var idleTitle = "—"
    private var isRecording = false

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        title = idleTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool {
        isRecording
    }

    /// 녹화 중이 아닐 때 표시할 현재 단축키 텍스트.
    func setIdleDisplay(_ text: String) {
        idleTitle = text.isEmpty ? "—" : text
        if !isRecording { title = idleTitle }
    }

    @objc private func beginRecording() {
        isRecording = true
        title = "Type shortcut…"
        // first responder 획득에 실패하면 키 입력이 오지 않으므로 즉시 원복(녹화 멈춤 방지).
        guard window?.makeFirstResponder(self) == true else {
            cancelRecording()
            return
        }
        onRecordingStateChanged?(true)
    }

    private func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        title = idleTitle
        onRecordingStateChanged?(false)
    }

    private func finishRecording(with shortcut: HotkeyShortcut) {
        isRecording = false
        title = shortcut.displayString
        onRecordingStateChanged?(false)
        onCapture?(shortcut)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRecording()
            return
        }
        // Tab은 녹화를 취소하고 정상 포커스 이동을 그대로 흘려보낸다(필드에 갇히지 않게).
        if event.keyCode == UInt16(kVK_Tab) {
            cancelRecording()
            super.keyDown(with: event)
            return
        }
        // 키 반복(꾹 누름)으로 의도치 않게 캡처되지 않도록 무시한다.
        if event.isARepeat { return }
        let carbonModifiers = CarbonModifier.mask(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            // 전역 단축키는 수정자가 최소 하나 필요하다.
            NSSound.beep()
            return
        }
        finishRecording(with: HotkeyShortcut(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers))
    }

    /// 녹화 중에는 ⌘ 기반 조합도 가로채 기록한다 — 메인 메뉴(⌘Q·⌘W·⌘C 등)가 채가기 전에.
    /// performKeyEquivalent는 키 윈도우 뷰 계층이 메뉴보다 먼저 받으므로 여기서 소비(true 반환).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { cancelRecording() }
        return super.resignFirstResponder()
    }
}
