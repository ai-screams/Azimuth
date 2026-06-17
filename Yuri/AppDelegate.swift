//
//  AppDelegate.swift
//  Yuri
//
//  Created by hanyul on 3/31/26.
//

import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private let permissionStatusMenuItem = NSMenuItem()
    private let frontmostAppTracker = FrontmostAppTracker()
    private let openAccessibilitySettingsMenuItem = NSMenuItem(
        title: "Open Accessibility Settings…",
        action: #selector(openAccessibilitySettings(_:)),
        keyEquivalent: ""
    )
    #if DEBUG
        private let debugResolutionMenuItem = NSMenuItem()
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureActivationPolicy()
        configureStatusItem()
        refreshPermissionState()
        debugShowSettingsOnLaunchIfNeeded()
        #if DEBUG
            configureDebugWindowProbe()
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(sender)
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshPermissionState()
        #if DEBUG
            updateDebugResolutionMenuItem()
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func openSettings(_ sender: Any?) {
        guard let controller = settingsWindowController ?? makeSettingsWindowController() else {
            NSSound.beep()
            return
        }

        settingsWindowController = controller
        controller.showWindow(sender)
        controller.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        _ = AccessibilityPermissionService.requestPrompt()

        guard AccessibilityPermissionService.openSystemSettings() else {
            NSSound.beep()
            return
        }
    }

    @objc private func handleDidBecomeActive(_ notification: Notification) {
        refreshPermissionState()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let button = item.button

        button?.image = nil
        button?.title = "Yuri"
        button?.toolTip = "Yuri"
        item.menu = makeStatusMenu()
        item.isVisible = true

        statusItem = item
        NSLog("Yuri status item created. button=%@", String(describing: button))
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        permissionStatusMenuItem.isEnabled = false
        menu.addItem(permissionStatusMenuItem)

        openAccessibilitySettingsMenuItem.target = self
        menu.addItem(openAccessibilitySettingsMenuItem)

        menu.addItem(.separator())

        #if DEBUG
            debugResolutionMenuItem.isEnabled = false
            debugResolutionMenuItem.title = "Focused window: open menu to check"
            menu.addItem(debugResolutionMenuItem)

            let identifyItem = NSMenuItem(
                title: "Identify Focused Window (Debug)",
                action: #selector(identifyFocusedWindowDebug(_:)),
                keyEquivalent: ""
            )
            identifyItem.target = self
            menu.addItem(identifyItem)

            for command in WindowCommand.allCases {
                let item = NSMenuItem(
                    title: "\(command.displayName) (Debug)",
                    action: #selector(runWindowCommandDebug(_:)),
                    keyEquivalent: ""
                )
                item.tag = WindowCommand.allCases.firstIndex(of: command) ?? 0
                item.target = self
                menu.addItem(item)
            }
            menu.addItem(.separator())
        #endif

        let settingsItem = NSMenuItem(
            title: "Open Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Yuri",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func makeSettingsWindowController() -> NSWindowController? {
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

    private func refreshPermissionState() {
        let status = AccessibilityPermissionService.currentStatus()

        permissionStatusMenuItem.title = status.menuTitle
        openAccessibilitySettingsMenuItem.isHidden = status.isTrusted

        statusItem?.button?.title = status.isTrusted ? "Yuri" : "Yuri!"
        statusItem?.button?.toolTip = status.isTrusted
            ? "Yuri"
            : "Yuri needs Accessibility access"
    }

    private func debugShowSettingsOnLaunchIfNeeded() {
        #if DEBUG
            openSettings(nil)
            NSLog("Yuri debug launch opened settings window.")
        #endif
    }

    private func configureActivationPolicy() {
        #if DEBUG
            NSApp.setActivationPolicy(.regular)
        #else
            NSApp.setActivationPolicy(.accessory)
        #endif
    }
}

#if DEBUG
    extension AppDelegate {
        private func configureDebugWindowProbe() {
            frontmostAppTracker.onChange = { [weak self] _ in
                guard let self else { return }
                NSLog("[Yuri P3] activate -> %@", currentResolutionText())
            }
        }

        @objc private func identifyFocusedWindowDebug(_ sender: Any?) {
            let text = currentResolutionText()
            NSLog("[Yuri P3] menu -> %@", text)

            let alert = NSAlert()
            alert.messageText = "Focused Window (Debug)"
            alert.informativeText = text
            alert.runModal()
        }

        private func updateDebugResolutionMenuItem() {
            debugResolutionMenuItem.title = "Focused: \(currentResolutionText())"
        }

        @objc private func runWindowCommandDebug(_ sender: NSMenuItem) {
            let commands = WindowCommand.allCases
            guard sender.tag >= 0, sender.tag < commands.count else { return }
            let command = commands[sender.tag]

            switch WindowCommandExecutor.run(command, tracker: frontmostAppTracker) {
            case let .success(frame):
                NSLog("[Yuri P4] %@ -> OK %@", command.displayName, NSStringFromRect(frame))
            case let .failure(error):
                NSLog("[Yuri P4] %@ -> FAIL %@", command.displayName, error.userFacingMessage)
                NSSound.beep()
            }
        }

        private func currentResolutionText() -> String {
            let appName = frontmostAppTracker.lastFocusedApp?.localizedName ?? "—"
            switch FocusedWindowResolver.resolveFrontmostFocusedWindow(tracker: frontmostAppTracker) {
            case let .success(window):
                let width = Int(window.frame.size.width)
                let height = Int(window.frame.size.height)
                return "\(appName) → OK \(width)×\(height) (\(window.subrole))"
            case let .failure(error):
                return "\(appName) → \(error.userFacingMessage)"
            }
        }
    }
#endif
