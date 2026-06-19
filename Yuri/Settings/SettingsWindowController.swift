import Cocoa

@MainActor
final class SettingsWindowController {
    private var windowController: NSWindowController?
    private let preferencesStore: PreferencesStore
    private let launchService: LaunchAtLoginService
    private let onPresetChange: () -> Void

    init(
        preferencesStore: PreferencesStore,
        launchService: LaunchAtLoginService,
        onPresetChange: @escaping () -> Void
    ) {
        self.preferencesStore = preferencesStore
        self.launchService = launchService
        self.onPresetChange = onPresetChange
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
            onPresetChange: onPresetChange
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Yuri Settings"
        window.contentViewController = viewController
        return NSWindowController(window: window)
    }
}
