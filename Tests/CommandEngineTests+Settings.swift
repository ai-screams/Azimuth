// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 설정 화면의 판단(알림 토글).
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).

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
}
