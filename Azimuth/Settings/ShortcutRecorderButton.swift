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
        let carbonModifiers = Self.carbonModifierMask(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            // 전역 단축키는 수정자가 최소 하나 필요하다.
            NSSound.beep()
            return
        }
        finishRecording(with: HotkeyShortcut(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers))
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { cancelRecording() }
        return super.resignFirstResponder()
    }

    /// NSEvent 수정자 플래그 → Carbon 수정자 마스크.
    static func carbonModifierMask(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let device = flags.intersection(.deviceIndependentFlagsMask)
        var mask: UInt32 = 0
        if device.contains(.control) { mask |= UInt32(controlKey) }
        if device.contains(.option) { mask |= UInt32(optionKey) }
        if device.contains(.shift) { mask |= UInt32(shiftKey) }
        if device.contains(.command) { mask |= UInt32(cmdKey) }
        return mask
    }
}
