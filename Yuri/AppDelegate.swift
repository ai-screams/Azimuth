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
    private let hotkeyService = HotkeyService()
    private let preferencesStore = PreferencesStore()
    private let launchAtLoginService = LaunchAtLoginService()
    private var registrationFailureIdentifiers: Set<String> = []
    private lazy var settingsWindowController = SettingsWindowController(
        preferencesStore: preferencesStore,
        launchService: launchAtLoginService,
        onHotkeysChanged: { [weak self] in self?.reloadHotkeys() },
        registrationFailures: { [weak self] in self?.registrationFailureIdentifiers ?? [] },
        setHotkeysSuspended: { [weak self] suspended in self?.setHotkeysSuspended(suspended) },
        setMenuBarIconHidden: { [weak self] hidden in self?.statusBarController.setVisible(!hidden) }
    )
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
        statusBarController.setVisible(!preferencesStore.menuBarIconHidden)
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
        let resolved = BindingResolver.resolve(
            preset: preferencesStore.activePreset,
            overrides: preferencesStore.customShortcuts
        )
        let bindings = BindingResolver.enabled(
            resolved,
            disabledCommands: preferencesStore.disabledCommandIdentifiers,
            disabledGroups: preferencesStore.disabledGroupTokens
        )
        let failed = hotkeyService.reload(bindings) { [weak self] command in
            self?.runHotkeyCommand(command)
        }
        registrationFailureIdentifiers = Set(failed.map(\.command.identifier))
    }

    /// 단축키 녹화 중에는 전역 핫키를 모두 해제하고, 끝나면 다시 등록한다(녹화 조합의 오발화 방지).
    private func setHotkeysSuspended(_ suspended: Bool) {
        if suspended {
            hotkeyService.unregisterAll()
        } else {
            reloadHotkeys()
        }
    }

    private func runHotkeyCommand(_ command: WindowCommand) {
        let result = WindowCommandExecutor.run(command, tracker: frontmostAppTracker, undoStore: windowUndoStore)
        switch result {
        case .success:
            break
        case .failure(.transient):
            // Space 전환·애니메이션 중 일시적 실패는 비프 없이 조용히 무시한다.
            Log.windows.debug("Hotkey \(command.displayName, privacy: .public) -> transient, skipped")
        case let .failure(error):
            if preferencesStore.soundFeedbackEnabled {
                NSSound.beep()
            }
            Log.windows.debug(
                "Hotkey \(command.displayName, privacy: .public) -> FAIL \(error.userFacingMessage, privacy: .public)"
            )
        }
    }

    @objc private func handleDidBecomeActive(_ notification: Notification) {
        // 사용자가 System Settings에서 권한을 바꿨을 수 있으므로 캐시를 비우고 다시 조회한다.
        AccessibilityPermissionService.invalidateCache()
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
