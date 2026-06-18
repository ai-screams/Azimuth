import Cocoa

final class SettingsWindowController {
    private var windowController: NSWindowController?

    func show() {
        let controller = windowController ?? makeWindowController()
        windowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindowController() -> NSWindowController {
        let viewController = ViewController()
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
