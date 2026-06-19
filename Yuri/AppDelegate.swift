//
//  AppDelegate.swift
//  Yuri
//
//  Created by hanyul on 3/31/26.
//

import Cocoa
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let frontmostAppTracker = FrontmostAppTracker()
    private let windowUndoStore = WindowUndoStore()
    private let settingsWindowController = SettingsWindowController()
    private let hotkeyService = HotkeyService()
    private let preferencesStore = PreferencesStore()
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
        reloadHotkeys()
        debugShowSettingsOnLaunchIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
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

    private func reloadHotkeys() {
        hotkeyService.reload(preferencesStore.activePreset.bindings) { [weak self] command in
            self?.runHotkeyCommand(command)
        }
    }

    private func runHotkeyCommand(_ command: WindowCommand) {
        let result = WindowCommandExecutor.run(command, tracker: frontmostAppTracker, undoStore: windowUndoStore)
        switch result {
        case .success:
            break
        case let .failure(error):
            NSSound.beep()
            Log.windows.debug(
                "Hotkey \(command.displayName, privacy: .public) -> FAIL \(error.userFacingMessage, privacy: .public)"
            )
        }
    }

    @objc private func handleDidBecomeActive(_ notification: Notification) {
        statusBarController.refreshPermissionState()
    }

    @objc private func handleScreenParametersChanged(_ notification: Notification) {
        // 디스플레이 연결/해제·배치 변경 시 저장된 절대 frame은 무효 → undo 이력을 버린다.
        windowUndoStore.clearAll()
        Log.windows.debug("Screen parameters changed; cleared window undo history.")
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
