//
//  CommandFailureNotifier.swift
//  Azimuth
//
//  명령 실패 알림용 UNUserNotificationCenter 어댑터. 알림 권한은 절대 선요청하지 않는다 —
//  Settings의 "Notify when a command fails" 토글을 켜는 순간에만 requestAuthorization이
//  불린다(opt-in). 거부되면 호출부(ViewController)가 토글을 되돌린다.
//

import UserNotifications

@MainActor
final class CommandFailureNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self // 앱이 포그라운드여도 배너를 표시한다(아래 willPresent)
    }

    /// true = 허용. 최초 1회만 시스템 프롬프트가 뜨고, 이후에는 저장된 결정을 그대로 돌려준다
    /// (시스템 설정에서 거부된 상태면 프롬프트 없이 false).
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    /// 실패한 명령 이름을 제목, 사유(userFacingMessage)를 본문으로 즉시 전달한다.
    func postCommandFailure(commandName: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(commandName) failed"
        content.body = message
        // trigger: nil → 즉시 전달
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
