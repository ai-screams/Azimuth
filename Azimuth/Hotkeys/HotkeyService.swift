//
//  HotkeyService.swift
//  Azimuth
//

import Carbon.HIToolbox
import Cocoa
import os

@MainActor
final class HotkeyService {
    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1
    private let signature: OSType = 0x415A_4D54 // 'AZMT'

    /// keyCode=가상 키코드, modifiers=Carbon 수정자(controlKey|optionKey 등).
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        // handler가 없으면 hotkey 등록이 성공해도 이벤트가 전달되지 않는다(유령 단축키) — 등록을
        // 시작하지 않고 실패로 보고한다(감사 M-5). Settings 배지 문구("In use by system")는 이 경우
        // 원인과 다르지만, 아무 표시 없이 죽어 있는 것보다는 낫다. 실제 원인은 아래 로그가 남긴다.
        guard installEventHandlerIfNeeded() else { return false }
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.app.error("RegisterEventHotKey failed (status \(status), keyCode \(keyCode))")
            return false
        }
        handlers[id] = action
        hotKeyRefs.append(ref)
        return true
    }

    /// 모든 바인딩을 재등록하고, 등록에 실패한 바인딩(보통 시스템/타앱이 이미 점유)을 반환한다.
    @discardableResult
    func reload(_ bindings: [HotkeyBinding], perform: @escaping (WindowCommand) -> Void) -> [HotkeyBinding] {
        unregisterAll()
        var failed: [HotkeyBinding] = []
        for binding in bindings {
            let command = binding.command
            let registered = register(keyCode: binding.keyCode, modifiers: binding.modifiers) {
                perform(command)
            }
            if !registered { failed.append(binding) }
        }
        return failed
    }

    func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    fileprivate func handle(id: UInt32) {
        handlers[id]?()
    }

    /// 설치돼 있으면 true. 실패하면 `eventHandlerRef`를 nil로 남겨 다음 등록에서 다시 시도한다.
    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandlerRef == nil else { return true }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            userData,
            &ref
        )
        guard status == noErr, let ref else {
            Log.app.error("InstallEventHandler failed (status \(status)) — hotkeys would never fire")
            if let ref { RemoveEventHandler(ref) }
            return false
        }
        eventHandlerRef = ref
        return true
    }
}

private nonisolated func hotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let id = hotKeyID.id
    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        service.handle(id: id)
    }
    return noErr
}
