// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 단축키 치트시트(#182)의 층 고르기, 키보드 지도, 띄우고 닫는 흐름.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).

import Carbon.HIToolbox
import Foundation

extension CommandEngineTests {

    // 이것을 실패시키는 것: 수정키가 일부만 같은 바인딩을 층에 넣는 것(⌃⌥ 층에 ⌃⌥⇧ 명령),
    // 바인딩 없는 조합에도 층을 만드는 것, 지도 밖 키를 버리는 것, 층 이름의 그룹 순서.
    static func testCheatSheetLayer() {
        let base = UInt32(controlKey | optionKey)
        let bindings = HotkeyPreset.standard.bindings
        let layer = CheatSheetLayer.make(bindings: bindings, modifiers: base)
        expectName("⌃⌥ left arrow", "\(layer?.mapped[0x7B].map(\.identifier) ?? "nil")",
                   WindowCommand.snapThrow(.left).identifier)
        expectName("⌃⌥ return is maximize", "\(layer?.mapped[0x24] == .maximize)", "true")
        expectName("⌃⌥ layer excludes ⌃⌥⇧", "\(layer?.mapped.values.contains(.maximizeGaps) == true)", "false")
        expectName("⌃⌥ layer title", layer?.title ?? "nil", "Maximize · Undo · Center · Halves · Thirds · Two-Thirds")
        expectName("shift alone has no layer", "\(CheatSheetLayer.make(bindings: bindings, modifiers: UInt32(shiftKey)) == nil)", "true")

        let f5 = HotkeyBinding(command: .maximize, keyCode: 0x60, modifiers: base)
        let custom = CheatSheetLayer.make(bindings: [f5], modifiers: base)
        expectName("off-map key goes to others", "\(custom?.others.count ?? -1)/\(custom?.mapped.count ?? -1)", "1/0")

        // 줄마다 키 + 간격의 합이 같다(오른쪽 끝이 맞음). 채우는 키는 보통 키보다 좁지 않다.
        // 이것을 실패시키는 것: 채우는 키 계산에서 간격을 빼먹는 것, 기준 너비를 바꾸는 것.
        let widths = CheatSheetKeyboard.widths(unit: 44, spacing: 4)
        let rowTotals = Set(widths.map { Int(($0.reduce(0, +) + Double($0.count - 1) * 4).rounded()) })
        expectName("rows share one width", "\(rowTotals)", "[690]")
        expectName("fill keys are not narrower than a key", "\(widths.joined().allSatisfy { $0 >= 44 })", "true")

        // 두 프리셋의 모든 바인딩이 지도 위에 있다(다른 키 줄은 사용자 지정용).
        let offMap = HotkeyPreset.allCases.flatMap(\.bindings).filter { !CheatSheetKeyboard.keyCodes.contains($0.keyCode) }
        expectName("every preset key is on the map", "\(offMap.count)", "0")
    }

    // 이것을 실패시키는 것: 수정키를 누르자마자 띄우는 것, 명령 키를 누른 뒤에도 띄우는 것, 같은 조합으로 다시
    // 띄우는 것, 떼도 닫지 않는 것, 띄운 채 조합을 바꿀 때 닫았다 다시 기다리는 것, 늦게 온 타이머로 띄우는 것.
    static func testCheatSheetTrigger() {
        typealias Trigger = CheatSheetTrigger
        func run(_ events: [Trigger.Event]) -> String {
            var state = Trigger.State.idle
            var effects: [String] = []
            for event in events {
                let (next, effect) = Trigger.reduce(state, event)
                state = next
                effects.append("\(effect)")
            }
            return "\(state) | " + effects.joined(separator: ",")
        }
        let held = Trigger.Event.modifiers(3, hasLayer: true)
        let released = Trigger.Event.modifiers(0, hasLayer: false)
        expectName("hold then wait shows", run([held, .delayElapsed]), "shown(3) | schedule,show(3)")
        expectName("release closes", run([held, .delayElapsed, released]), "idle | schedule,show(3),hide")
        expectName("quick shortcut never shows", run([held, .keyPressed, .delayElapsed]),
                   "suppressed(3) | schedule,cancel,none")
        expectName("same combo stays quiet", run([held, .keyPressed, held]), "suppressed(3) | schedule,cancel,none")
        expectName("key while shown hides", run([held, .delayElapsed, .keyPressed]),
                   "suppressed(3) | schedule,show(3),hide")
        expectName("switching layer while shown", run([held, .delayElapsed, .modifiers(7, hasLayer: true)]),
                   "shown(7) | schedule,show(3),show(7)")
        expectName("release before delay cancels", run([held, released, .delayElapsed]),
                   "idle | schedule,cancel,none")
        expectName("new combo after suppress waits again", run([held, .keyPressed, .modifiers(7, hasLayer: true)]),
                   "pending(7) | schedule,cancel,schedule")
        expectName("modifier without layer does nothing", run([.modifiers(2, hasLayer: false)]), "idle | none")
    }

    // 이것을 실패시키는 것: 치트시트를 꺼진 채 시작하는 것, 손으로 바꾼 지연 값(예: 300)을 그대로 쓰는 것,
    // 저장한 선택지를 읽지 못하는 것.
    @MainActor
    static func testCheatSheetPreferences() {
        withTestDefaults { defaults in
            let store = PreferencesStore(defaults: defaults)
            expectName("cheat sheet starts on", "\(store.cheatSheetEnabled)", "true")
            store.cheatSheetEnabled = false
            expectName("cheat sheet off persists", "\(PreferencesStore(defaults: defaults).cheatSheetEnabled)", "false")
            expectName("delay defaults to 0.8 s", "\(store.cheatSheetDelay.seconds)", "0.8")
            store.cheatSheetDelay = .long
            expectName("delay persists", "\(PreferencesStore(defaults: defaults).cheatSheetDelay)", "long")
            defaults.set(300, forKey: "cheatSheetDelayMilliseconds")
            expectName("hand-edited delay reads as standard", "\(store.cheatSheetDelay)", "standard")
        }
    }
}
