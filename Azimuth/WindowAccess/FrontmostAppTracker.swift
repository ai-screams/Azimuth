import Cocoa

@MainActor
final class FrontmostAppTracker {
    private(set) var lastFocusedApp: NSRunningApplication?
    var onChange: ((NSRunningApplication) -> Void)?

    /// 명령 대상 앱: 추적된 직전 non-Azimuth 앱, 없으면 현재 frontmost. "어느 앱"
    /// 정책을 한 곳에 모은다.
    var targetApplication: NSRunningApplication? {
        lastFocusedApp ?? NSWorkspace.shared.frontmostApplication
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
