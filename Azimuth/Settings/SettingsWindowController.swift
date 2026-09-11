import Cocoa

@MainActor
final class SettingsWindowController {
    /// 폭은 고정(가로 리사이즈 비활성). 콘텐츠 내부 폭(480/512)에 맞춰 튜닝된 값이다.
    private static let windowWidth: CGFloat = 560

    private var windowController: NSWindowController?
    private let preferencesStore: PreferencesStore
    private let launchService: LaunchAtLoginService
    private let onHotkeysChanged: () -> Void
    private let registrationFailures: () -> Set<String>
    private let setHotkeysSuspended: (Bool) -> Void
    private let setMenuBarIconHidden: (Bool) -> Void
    private let setResolveTimeout: (Float) -> Void
    private let checkForUpdates: () -> Void
    private let requestNotificationAuthorization: () async -> NotificationAuthorizationResult

    init(
        preferencesStore: PreferencesStore,
        launchService: LaunchAtLoginService,
        onHotkeysChanged: @escaping () -> Void,
        registrationFailures: @escaping () -> Set<String>,
        setHotkeysSuspended: @escaping (Bool) -> Void,
        setMenuBarIconHidden: @escaping (Bool) -> Void,
        setResolveTimeout: @escaping (Float) -> Void,
        checkForUpdates: @escaping () -> Void,
        requestNotificationAuthorization: @escaping () async -> NotificationAuthorizationResult
    ) {
        self.preferencesStore = preferencesStore
        self.launchService = launchService
        self.onHotkeysChanged = onHotkeysChanged
        self.registrationFailures = registrationFailures
        self.setHotkeysSuspended = setHotkeysSuspended
        self.setMenuBarIconHidden = setMenuBarIconHidden
        self.setResolveTimeout = setResolveTimeout
        self.checkForUpdates = checkForUpdates
        self.requestNotificationAuthorization = requestNotificationAuthorization
    }

    func show() {
        let controller = windowController ?? makeWindowController()
        windowController = controller
        if let window = controller.window {
            centerOnActiveScreen(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    /// 멀티모니터에서 창이 다른 디스플레이에 묻히지 않게, 마우스가 있는 화면 중앙에 배치한다.
    private func centerOnActiveScreen(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        ))
    }

    private func makeWindowController() -> NSWindowController {
        let viewController = ViewController(
            preferencesStore: preferencesStore,
            launchService: launchService,
            setMenuBarIconHidden: setMenuBarIconHidden,
            checkForUpdates: checkForUpdates,
            requestNotificationAuthorization: requestNotificationAuthorization
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowWidth, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Azimuth Settings"
        // 컨트롤러가 창을 재사용하므로 닫을 때(⌘W·빨간버튼) 해제하지 않는다(ARC 과해제/재오픈 크래시 방지).
        window.isReleasedWhenClosed = false
        let shortcutsPane = ShortcutsPaneViewController(
            preferencesStore: preferencesStore,
            onHotkeysChanged: onHotkeysChanged,
            registrationFailures: registrationFailures,
            setHotkeysSuspended: setHotkeysSuspended
        )
        let advancedPane = AdvancedPaneViewController(
            preferencesStore: preferencesStore,
            setResolveTimeout: setResolveTimeout
        )
        let tabController = SettingsTabController(panes: [viewController, shortcutsPane, advancedPane])
        window.contentViewController = tabController
        applyResizeLimits(to: window, tabController: tabController)
        window.center()
        return NSWindowController(window: window)
    }

    /// 폭은 디자인 값(560)으로 고정하고, 세로만 리사이즈를 허용한다.
    /// 최소 높이 아래로 줄여도 페인 내부 스크롤뷰가 콘텐츠를 스크롤하므로 어떤 섹션도 잘리지 않는다.
    /// 최대 높이는 선택된 페인의 자연 높이로 두어, 그 이상 늘려 빈 공간이 생기지 않게 한다.
    private func applyResizeLimits(to window: NSWindow, tabController: SettingsTabController) {
        // 폭을 확정한 뒤 자연 높이를 잰다. 탭 컨트롤러 도입 후로 이 호출은 방어가 아니라 **필수**다 —
        // 탭뷰에 막 추가된 페인 뷰의 기본 프레임은 560x640이 아니라 500x500이고, 이 setContentSize가
        // 탭뷰를 통해 페인을 창 폭에 맞추는 유일한 트리거다. 지우면 자연 높이가 틀린 폭 기준으로
        // 계산되어 라벨 줄바꿈이 달라지는데, 이 값을 테스트하는 하네스가 없어 아무 것도 못 잡는다.
        window.setContentSize(NSSize(width: Self.windowWidth, height: 640))
        let height = tabController.preferredWindowHeight()
        window.contentMinSize = NSSize(width: Self.windowWidth, height: SettingsTabController.minWindowHeight)
        window.contentMaxSize = NSSize(width: Self.windowWidth, height: height)
        window.setContentSize(NSSize(width: Self.windowWidth, height: height))
    }
}
