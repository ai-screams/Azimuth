// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 설정 화면의 판단(알림 토글, 단축키 녹화의 키 처리와 녹화 상태).
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).

import Carbon.HIToolbox
import Foundation

extension CommandEngineTests {

    // 알림 토글: 권한 결과 × 기다리는 사이 껐는지. 이것을 실패시키는 것: 결과별 분기를 바꾸거나
    // "기다리는 사이 껐다"를 무시하는 것.
    static func testNotifyToggleDecision() {
        func outcome(_ result: NotificationAuthorizationResult, _ stillOn: Bool) -> String {
            let decided = NotifyToggleDecision.afterRequest(result, toggleStillOn: stillOn)
            return "stored=\(decided.stored) on=\(decided.toggleOn) hint=\(decided.showsSettingsHint)"
        }
        expectName("granted", outcome(.granted, true), "stored=true on=true hint=false")
        expectName("denied shows the settings hint", outcome(.denied, true), "stored=false on=false hint=true")
        expectName("failed reverts without a hint", outcome(.failed, true), "stored=false on=false hint=false")
        expectName("turned off while waiting, granted", outcome(.granted, false), "stored=false on=false hint=false")
        expectName("turned off while waiting, denied", outcome(.denied, false), "stored=false on=false hint=false")
    }

    // 녹화 중 키 하나: 순서(Esc → Tab → 반복 → 수정키)가 판단이다. 이것을 실패시키는 것: 검사 순서를 바꾸는 것
    // (수정키 붙은 Esc가 기록되거나 반복 키가 거부음을 내는 것), 수정키 검사를 빼는 것, 키 코드 상수가 틀린 것.
    static func testShortcutCapturePolicy() {
        func decide(_ keyCode: Int, _ modifiers: Int, repeat isRepeat: Bool = false) -> ShortcutCaptureOutcome {
            ShortcutCapturePolicy.decide(
                keyCode: UInt16(keyCode), carbonModifiers: UInt32(modifiers), isRepeat: isRepeat
            )
        }
        let ctrlOpt = controlKey | optionKey
        func name(_ outcome: ShortcutCaptureOutcome) -> String {
            switch outcome {
            case .cancel: "cancel"
            case .cancelAndMoveFocus: "cancelAndMoveFocus"
            case .ignore: "ignore"
            case .reject: "reject"
            case let .capture(shortcut): "capture \(shortcut.keyCode) \(shortcut.modifiers)"
            }
        }
        expectName("escape constant", "\(ShortcutCapturePolicy.escapeKeyCode)", "\(kVK_Escape)")
        expectName("tab constant", "\(ShortcutCapturePolicy.tabKeyCode)", "\(kVK_Tab)")
        expectName("escape cancels", name(decide(kVK_Escape, 0)), "cancel")
        expectName("escape with modifiers still cancels", name(decide(kVK_Escape, ctrlOpt)), "cancel")
        expectName("tab moves focus", name(decide(kVK_Tab, ctrlOpt)), "cancelAndMoveFocus")
        expectName("repeat is ignored before the modifier check", name(decide(kVK_ANSI_A, 0, repeat: true)), "ignore")
        expectName("no modifier is rejected", name(decide(kVK_ANSI_A, 0)), "reject")
        expectName("combo is captured", name(decide(kVK_LeftArrow, ctrlOpt)), "capture \(kVK_LeftArrow) \(ctrlOpt)")
    }

    // 녹화 상태와 전역 단축키 일시 정지. 화면이 겪는 순서대로 흘려 보고 "녹화 중 = 멈춤"이 끝까지 맞는지 본다.
    // 이것을 실패시키는 것: 다른 줄로 옮길 때 다시 멈추거나 재개하는 것, 이전 칸의 늦은 알림을 받아들이는 것
    // (녹화 중인데 단축키가 다시 켜짐), 같은 줄을 다시 눌러도 취소하지 않는 것, 숨은 줄을 놓치는 것.
    static func testShortcutRecordingPolicy() {
        var recording: String?
        var suspended = false
        var suspendCalls = 0
        func apply(_ step: ShortcutRecordingStep?) {
            guard let step else { return }
            recording = step.recording
            if let suspend = step.suspend {
                suspended = suspend
                suspendCalls += 1
            }
        }
        func state() -> String {
            "recording=\(recording ?? "-") suspended=\(suspended) calls=\(suspendCalls)"
        }
        apply(ShortcutRecordingPolicy.toggle("a", current: recording))
        expectName("start a suspends", state(), "recording=a suspended=true calls=1")
        apply(ShortcutRecordingPolicy.toggle("b", current: recording))
        expectName("switch to b keeps suspended", state(), "recording=b suspended=true calls=1")
        apply(ShortcutRecordingPolicy.finish("a", current: recording))
        expectName("late finish from a is ignored", state(), "recording=b suspended=true calls=1")
        apply(ShortcutRecordingPolicy.finish("b", current: recording))
        expectName("finish b resumes", state(), "recording=- suspended=false calls=2")
        apply(ShortcutRecordingPolicy.finish("b", current: recording))
        expectName("second finish is ignored", state(), "recording=- suspended=false calls=2")
        apply(ShortcutRecordingPolicy.toggle("a", current: recording))
        apply(ShortcutRecordingPolicy.toggle("a", current: recording))
        expectName("clicking the same row cancels", state(), "recording=- suspended=false calls=4")

        let visible: Set<String> = ["a"]
        expectName("visible row", "\(ShortcutRecordingPolicy.isHidden(current: "a", visible: visible))", "false")
        expectName("hidden row", "\(ShortcutRecordingPolicy.isHidden(current: "b", visible: visible))", "true")
        expectName("not recording", "\(ShortcutRecordingPolicy.isHidden(current: nil, visible: []))", "false")
    }
}
