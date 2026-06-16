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
    private let openAccessibilitySettingsMenuItem = NSMenuItem(
        title: "Open Accessibility Settings…",
        action: #selector(openAccessibilitySettings(_:)),
        keyEquivalent: ""
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureActivationPolicy()
        configureStatusItem()
        refreshPermissionState()
        debugShowSettingsOnLaunchIfNeeded()

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
