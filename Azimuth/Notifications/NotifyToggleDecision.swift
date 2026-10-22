//
//  NotifyToggleDecision.swift
//  Azimuth
//
//  "Notify when a command fails" 토글을 켰을 때, 알림 권한 요청 결과로 무엇을 저장하고 보일지 정한다.
//  순수 값 판단이라 하네스에서 검사한다(설정 화면은 결과를 그대로 적용만 한다).
//

/// 알림 권한 요청 결과. UI가 셋을 다르게 처리하도록 세분화한다(값 타입 — UI 파일이
/// UserNotifications를 import하지 않아도 된다).
nonisolated enum NotificationAuthorizationResult {
    case granted
    /// 시스템 설정에서 꺼져 있거나 이미 거부됨 → 재요청해도 프롬프트가 뜨지 않으므로
    /// System Settings로 안내한다.
    case denied
    /// 요청 자체가 에러(예: DerivedData 실행 개발 빌드는 알림 미등록으로 UNErrorDomain 1).
    case failed
}

nonisolated struct NotifyToggleOutcome: Equatable {
    /// `PreferencesStore.notifyOnCommandFailure`에 저장할 값.
    let stored: Bool
    /// 토글이 보일 상태. 켜지 못했으면 되돌려 "켜져 보이는데 알림이 안 오는" 상태를 막는다.
    let toggleOn: Bool
    /// System Settings > Notifications로 안내하는 문구를 보일지.
    let showsSettingsHint: Bool
}

nonisolated enum NotifyToggleDecision {
    /// 권한 요청이 끝났을 때. `toggleStillOn`은 요청을 기다리는 사이 사용자가 토글을 다시 껐는지다.
    static func afterRequest(_ result: NotificationAuthorizationResult, toggleStillOn: Bool) -> NotifyToggleOutcome {
        // 기다리는 사이 껐다면 그 의사를 따른다(안 그러면 꺼져 보이는데 알림은 켜진다).
        guard toggleStillOn else {
            return NotifyToggleOutcome(stored: false, toggleOn: false, showsSettingsHint: false)
        }
        switch result {
        case .granted:
            return NotifyToggleOutcome(stored: true, toggleOn: true, showsSettingsHint: false)
        case .denied:
            return NotifyToggleOutcome(stored: false, toggleOn: false, showsSettingsHint: true)
        case .failed:
            // 요청 자체가 실패하면(개발 빌드의 알림 미등록 등) 앱이 System Settings에 나타나지도 않아
            // 안내가 막다른 길이 된다. 토글만 되돌린다.
            return NotifyToggleOutcome(stored: false, toggleOn: false, showsSettingsHint: false)
        }
    }
}
