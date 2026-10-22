import Cocoa
import SwiftUI

/// 설정 창 하나를 만들고 보이는 일만 맡는다. 화면은 SwiftUI(`SettingsRootView`)이고, 값과 동작은 `SettingsModel`이 가진다.
@MainActor
final class SettingsWindowController {
    /// 처음 열 때의 콘텐츠 크기와 최소 크기. 사이드바(약 200pt) + grouped Form이 줄바꿈 없이 들어가는 값이다.
    /// 높이는 가장 긴 About 화면이 스크롤 없이 들어가는 값(560에서 약 32pt 넘쳤다).
    private static let initialSize = NSSize(width: 760, height: 600)
    private static let minimumSize = NSSize(width: 640, height: 420)

    private let model: SettingsModel
    private var windowController: NSWindowController?
    private var activationObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?
    /// 권한이 없는 동안만 도는 주기 확인(`PermissionWatchPolicy`). 권한이 생기거나 창이 닫히면 멈춘다.
    private var permissionTimer: Timer?

    init(dependencies: SettingsDependencies) {
        model = SettingsModel(dependencies: dependencies)
        // 사용자가 System Settings에서 권한·로그인 항목·알림을 바꾸고 돌아오면 다시 읽는다.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkPermission() // 다음 확인을 기다리지 않고, 권한 줄이 먼저 갱신되기 전에 잡는다
                self?.model.appDidBecomeActive()
            }
        }
    }

    /// Sparkle이 확인을 받을 수 있는지(AppDelegate가 업데이터를 관찰해 알려 준다).
    func setCanCheckForUpdates(_ canCheck: Bool) {
        model.canCheckForUpdates = canCheck
    }

    func show(pane: SettingsModel.Pane? = nil) {
        let controller = windowController ?? makeWindowController()
        windowController = controller
        if let pane { model.selection = pane }
        model.clearPermissionJustGranted()
        model.refresh()
        if let window = controller.window {
            window.centerOnMouseScreen()
        }
        NSApp.bringToFront()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        checkPermission()
    }

    private func makeWindowController() -> NSWindowController {
        let hosting = NSHostingController(rootView: SettingsRootView(model: model))
        // 창 크기는 이 컨트롤러가 정한다. 콘텐츠의 선호 크기를 따라가면 화면을 바꿀 때마다 창이 튄다.
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        // 처음 연 화면의 제목. 이후 바뀌는 제목은 각 화면의 navigationTitle이 정한다(처음에는 덮어쓰지 않는다).
        window.title = (model.selection ?? .general).title
        window.toolbarStyle = .unified
        // 컨트롤러가 창을 재사용하므로 닫을 때(⌘W·빨간버튼) 해제하지 않는다(ARC 과해제/재오픈 크래시 방지).
        window.isReleasedWhenClosed = false
        window.setContentSize(Self.initialSize)
        window.contentMinSize = Self.minimumSize
        window.center()
        // 창을 닫을 때 SwiftUI가 화면을 내리는 알림(onDisappear)을 늘 보내지는 않는다. 녹화 중이면 여기서 끝내
        // 전역 단축키가 멈춘 채 남지 않게 한다.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.model.shortcuts.cancelRecording()
                self?.stopPermissionWatch()
            }
        }
        return NSWindowController(window: window)
    }

    /// 권한을 다시 읽고 `PermissionWatchPolicy`대로 주기 확인을 켜거나 끈다. macOS는 권한 변경을 알리는
    /// 문서화된 알림을 주지 않는다. 권한을 찾았다고 알리는 것은 권한 없이 시작한 확인이 돌고 있을 때뿐이다.
    private func checkPermission() {
        AccessibilityPermissionService.invalidateCache()
        let trusted = AccessibilityPermissionService.currentStatus().isTrusted
        let visible = windowController?.window?.isVisible ?? false
        switch PermissionWatchPolicy.step(windowVisible: visible, isTrusted: trusted) {
        case .keepWatching:
            guard permissionTimer == nil else { return }
            let interval = PermissionWatchPolicy.interval
            permissionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkPermission() }
            }
        case .granted:
            if permissionTimer != nil { model.permissionDidBecomeGranted() }
            stopPermissionWatch()
        case .stop:
            stopPermissionWatch()
        }
    }

    private func stopPermissionWatch() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }
}
