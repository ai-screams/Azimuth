//
//  AppDelegate.swift
//  Azimuth
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
        // 표준 메인 메뉴(App·Edit·Window)를 설치한다. 없으면 ⌘Q·⌘W·텍스트 편집이
        // 어디서도 처리되지 않아 경고음만 난다(.accessory 빌드도 키 equivalent는 동작).
        NSApp.mainMenu = MainMenuBuilder.make(
            appName: "Azimuth",
            actions: .init(
                target: self,
                about: #selector(showAboutPanel(_:)),
                settings: #selector(openSettings(_:))
            )
        )
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
        // 창 표시/닫힘에 따라 Dock 아이콘(활성화 정책)을 토글한다.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowVisibilityChanged(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        // DEBUG에서 설정창을 띄웠을 수 있으니 현재 창 상태에 맞춰 정책을 한 번 동기화한다.
        updateActivationPolicy()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindowController.show()
        return true
    }

    /// App 메뉴 "About Azimuth" 항목 액션. 아이콘·버전·설명·링크 버튼을 담은 커스텀 About 창을 띄운다.
    @objc private func showAboutPanel(_ sender: Any?) {
        AboutWindowController.shared.show()
    }

    /// App 메뉴 "Settings…"(⌘,) 항목 액션.
    @objc private func openSettings(_ sender: Any?) {
        settingsWindowController.show()
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
            Log.app.debug("Azimuth debug launch opened settings window.")
        #endif
    }

    /// 기본은 .accessory(Dock 아이콘 없음, 메뉴바 유틸). 창이 열리면 updateActivationPolicy가
    /// .regular로 올려 Dock 아이콘을 보이고, 모두 닫히면 다시 .accessory로 내린다.
    private func configureActivationPolicy() {
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func handleWindowVisibilityChanged(_ notification: Notification) {
        updateActivationPolicy()
    }

    /// willClose는 창이 아직 visible 목록에 있을 때 오므로, 다음 런루프에 다시 계산한다.
    @objc private func handleWindowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.updateActivationPolicy() }
    }

    /// 우리 창(설정/소개)이 하나라도 떠 있으면 Dock 아이콘(.regular), 없으면 숨김(.accessory).
    /// 메뉴바 상태 아이콘은 이와 무관하게 항상 유지된다(상시 접근 수단).
    private func updateActivationPolicy() {
        let hasWindow = NSApp.windows.contains { window in
            (window.isVisible || window.isMiniaturized) && window.styleMask.contains(.titled)
        }
        let policy: NSApplication.ActivationPolicy = hasWindow ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }
}
