//
//  CommandFailureNotifier.swift
//  Azimuth
//
//  명령 실패 알림용 UNUserNotificationCenter 어댑터. 알림 권한은 절대 선요청하지 않는다 —
//  Settings의 "Notify when a command fails" 토글을 켜는 순간에만 requestAuthorization이
//  불린다(opt-in). 거부되면 호출부(ViewController)가 토글을 되돌린다.
//

import os
import UserNotifications

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

@MainActor
final class CommandFailureNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self // 앱이 포그라운드여도 배너를 표시한다(아래 willPresent)
    }

    /// 최초 1회만 시스템 프롬프트가 뜨고, 이후에는 저장된 결정을 그대로 돌려준다. 이미 거부된
    /// 상태면 재요청해도 프롬프트가 안 뜨므로 요청 없이 .denied로 반환해 호출부가 안내로
    /// 연결하게 한다. 에러는 삼키지 않고 로깅한다(.failed).
    func requestAuthorization() async -> NotificationAuthorizationResult {
        let statusBefore = await center.notificationSettings().authorizationStatus
        if statusBefore == .denied {
            return .denied
        }
        do {
            let granted = try await center.requestAuthorization(options: [.alert])
            return granted ? .granted : .denied
        } catch {
            let nsError = error as NSError
            Log.app.error(
                "Notification requestAuthorization failed: \(nsError.domain, privacy: .public) \(nsError.code)"
            )
            return .failed
        }
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
