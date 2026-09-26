//
//  AccessibilityRequestPolicy.swift
//  Azimuth
//
//  "권한 설정 열기"를 눌렀을 때 macOS 권한 알림을 띄울지, System Settings를 바로 열지 정하는 순수 결정
//  (`make test` 대상). AppKit/AX를 import하지 않는다.
//
//  왜 필요한가: macOS는 손쉬운 사용 권한 알림("… would like to control this computer … [Open System Preferences]
//  (13+: Open System Settings) [Deny]")을 앱마다 처음 한 번만 띄우는 것으로 관찰된다(공개 계약은 아니다). 예전에는 알림을 띄우면서 곧바로
//  설정도 열어, 사용자가 알림에 답하기 전에 설정 창이 먼저 떴다. 권한 상태 API는 "아직 안 물음"과 "물었는데
//  거절"을 구분하지 못하므로, 알림을 **시도했는지**를 따로 기록해 판단한다.
//

import Foundation

nonisolated enum AccessibilityRequestAction: Equatable {
    /// 알림만 띄운다 — 알림의 "Open System Settings"가 설정을 연다.
    case systemPrompt
    /// 설정을 바로 연다(이미 알림을 시도했거나 이미 권한이 있다).
    case openSettings
}

nonisolated enum AccessibilityRequestPolicy {
    /// 권한이 없고 아직 알림을 시도하지 않았을 때만 알림. 그 밖에는 설정을 연다 — 이미 권한이 있어도 사용자가
    /// 직접 누른 것이므로 설정을 보여 준다.
    static func decide(isTrusted: Bool, didAttemptPrompt: Bool) -> AccessibilityRequestAction {
        !isTrusted && !didAttemptPrompt ? .systemPrompt : .openSettings
    }

    /// 기록이 없을 때(이 기능이 생기기 전 설치본)의 초기값. 예전 버전은 버튼을 누를 때마다 알림을 요청했으므로,
    /// 첫 실행을 이미 마친 설치본은 "시도함"으로 본다 — 그래야 이미 억제된 알림 때문에 첫 클릭이 헛돌지 않는다.
    /// 반드시 첫 실행 안내가 `didCompleteFirstRun`을 켜기 **전**(`PreferencesStore.init`)에 한 번만 정한다.
    static func initialAttemptFlag(recorded: Bool?, didCompleteFirstRun: Bool) -> Bool {
        recorded ?? didCompleteFirstRun
    }
}
