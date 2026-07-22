import Cocoa

@MainActor
final class FrontmostAppTracker {
    private(set) var lastFocusedApp: NSRunningApplication?
    var onChange: ((NSRunningApplication) -> Void)?

    /// 명령 대상 앱: 추적된 직전 non-Azimuth 앱, 없으면 현재 frontmost. "어느 앱"
    /// 정책을 한 곳에 모은다. 폴백에서도 자기 자신은 제외한다 — 기동 직후 다른 앱을 한 번도
    /// 활성화하지 않은 채(설정창만 띄운 상태) 단축키를 누르면 frontmost가 Azimuth 자신이라,
    /// 롤백된 "자기 설정창 스냅"이 이 구멍으로 되살아났다(자기창은 명령 대상이 아니다).
    var targetApplication: NSRunningApplication? {
        // 종료된 앱은 건너뛴다 — 다른 앱의 activation notification이 도착하기 전 짧은 구간에
        // 죽은 프로세스로 AX 요청을 보내는 것을 막는다(감사 L-2).
        if let lastFocusedApp, !lastFocusedApp.isTerminated { return lastFocusedApp }
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != selfPID
        else {
            return nil // 대상 없음 → noFrontmostApplication 실패(비프 + 메뉴 사유 행)
        }
        return frontmost
    }

    private let selfPID = ProcessInfo.processInfo.processIdentifier

    init() {
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != selfPID {
            lastFocusedApp = app
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != selfPID
        else {
            return
        }
        lastFocusedApp = app
        onChange?(app)
    }
}
