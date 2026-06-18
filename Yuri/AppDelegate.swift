//
//  AppDelegate.swift
//  Yuri
//
//  Created by hanyul on 3/31/26.
//

import Cocoa
import os

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let frontmostAppTracker = FrontmostAppTracker()
    private let windowUndoStore = WindowUndoStore()
    private let settingsWindowController = SettingsWindowController()
    private lazy var statusBarController = StatusBarController(
        frontmostAppTracker: frontmostAppTracker,
        windowUndoStore: windowUndoStore
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureActivationPolicy()
        statusBarController.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        statusBarController.install()
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
        settingsWindowController.show()
        return true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleDidBecomeActive(_ notification: Notification) {
        statusBarController.refreshPermissionState()
    }

    private func debugShowSettingsOnLaunchIfNeeded() {
        #if DEBUG
            settingsWindowController.show()
            Log.app.debug("Yuri debug launch opened settings window.")
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
