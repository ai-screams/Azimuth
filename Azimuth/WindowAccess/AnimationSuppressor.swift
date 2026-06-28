//
//  AnimationSuppressor.swift
//  Azimuth
//
//  대상 앱의 AX 애니메이션 속성(`AXEnhancedUserInterface`/`AXManualAccessibility`)을 프레임 쓰기 동안
//  잠시 꺼서 AX 쓰기를 동기·비애니메이션화한다(깜빡임 제거). 마지막 입력 +delay에 원복하며(PID별 디바운스),
//  VoiceOver 사용 중엔 끄지 않는다(보조기능 연결 끊김 방지). WindowFrameWriter가 소유하는 별도 관심사.
//

import AppKit
import ApplicationServices

@MainActor
final class AnimationSuppressor {
    private let enhancedUIAttribute = "AXEnhancedUserInterface"
    private let manualAccessibilityAttribute = "AXManualAccessibility"
    /// Chrome/Electron이 비동기로 다시 켜므로 즉시 복원은 레이스 → 마지막 입력 뒤 이 시간만큼 늦춰 복원.
    private let restoreDelay: TimeInterval

    /// PID별 억제 중(복원 대기)인 원본 상태. 연속 입력 때 라이브 값은 이미 false라 재판정이 불가하므로
    /// 원본을 여기 보관해 복원 시 사용한다. `appElement`는 PID 재사용 감지(동일성 비교)에도 쓴다.
    private struct State {
        let appElement: AXUIElement
        let enhanced: Bool
        let manual: Bool
    }

    private var suppressed: [pid_t: State] = [:]
    /// PID별 보류 중인 복원 작업(연속 입력 시 취소·교체 → 마지막 입력 기준으로 복원 시점이 미뤄진다).
    private var pendingRestores: [pid_t: DispatchWorkItem] = [:]

    init(restoreDelay: TimeInterval = 0.25) {
        self.restoreDelay = restoreDelay
    }

    /// 쓰기 전 애니메이션 속성을 끈다. 복원 스케줄이 필요하면 true 반환(호출자가 쓰기 후 `scheduleRestore` 호출).
    /// 이미 같은 앱을 억제 중이면 라이브 값이 false라 재판정 불가 → 원본을 유지하고 복원만 미룬다(true).
    func suppress(appElement: AXUIElement, pid: pid_t) -> Bool {
        // VoiceOver 사용 중엔 토글하지 않는다(화면낭독 연결이 끊겨 멈추는 것 방지 — 스냅 정밀도보다 우선).
        if NSWorkspace.shared.isVoiceOverEnabled { return false }
        // 연속 입력: 이미 끈 상태이므로 복원만 다시 미루면 된다. 단, pid 재사용(원래 앱이 죽고 같은 pid의
        // 다른 앱)일 수 있으니 엘리먼트 동일성으로 확인한다.
        if let existing = suppressed[pid], existing.appElement == appElement { return true }
        let enhanced = AXAttribute.bool(appElement, enhancedUIAttribute) == true
        let manual = AXAttribute.bool(appElement, manualAccessibilityAttribute) == true
        // 둘 다 꺼져있거나 없으면(네이티브 AppKit 앱) 건드릴 필요 없음 — 부작용·IPC 0.
        guard enhanced || manual else { return false }
        if enhanced { AXAttribute.set(appElement, enhancedUIAttribute, false) }
        if manual { AXAttribute.set(appElement, manualAccessibilityAttribute, false) }
        suppressed[pid] = State(appElement: appElement, enhanced: enhanced, manual: manual)
        return true
    }

    /// 마지막 입력 +restoreDelay에 원본 상태로 복원. 연속 입력 시 직전 작업을 취소·교체해 시점이 미뤄진다.
    func scheduleRestore(pid: pid_t) {
        pendingRestores[pid]?.cancel()
        let work = DispatchWorkItem { [self] in
            MainActor.assumeIsolated {
                if let state = suppressed[pid] {
                    if state.enhanced { AXAttribute.set(state.appElement, enhancedUIAttribute, true) }
                    if state.manual { AXAttribute.set(state.appElement, manualAccessibilityAttribute, true) }
                }
                suppressed[pid] = nil
                pendingRestores[pid] = nil
            }
        }
        pendingRestores[pid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: work)
    }
}
