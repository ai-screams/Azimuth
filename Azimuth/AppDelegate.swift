//
//  AppDelegate.swift
//  Azimuth
//
//  Created by hanyul on 3/31/26.
//

import Cocoa
import os
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Sparkle 자동 업데이트. startingUpdater: true로 즉시 시작 → 피드(appcast)를 주기적으로
    /// 확인한다. 자동 확인 동의는 Sparkle 표준 동작(둘째 실행 시 프롬프트)에 맡긴다.
    /// "Check for Updates…" 메뉴 항목의 타깃이 된다(canCheckForUpdates에 따라 자동 활성화).
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private let frontmostAppTracker = FrontmostAppTracker()
    private let windowUndoStore = WindowUndoStore()
    private let hotkeyService = HotkeyService()
    private let preferencesStore = PreferencesStore()
    private let launchAtLoginService = LaunchAtLoginService()
    /// 명령 실패 알림(opt-in). 권한 요청은 Settings 토글을 켤 때만 일어난다.
    private let failureNotifier = CommandFailureNotifier()
    private var registrationFailureIdentifiers: Set<String> = []
    /// 권한 미부여로 단축키가 실패했을 때 이번 세션에 이미 안내(Settings 유도)를 했는지.
    /// 매 실패마다 창을 띄우면 성가시므로 세션당 1회만.
    private var didNudgeForPermissionThisSession = false
    /// 가장 최근 단축키 명령이 실패했을 때의 (명령 이름, 사유). 상태바 메뉴에 노출해
    /// "beep만 나는" 실패의 이유를 설명한다. 다음 명령이 성공하면 지운다(세션 한정, 저장 안 함).
    private var lastCommandFailure: (commandName: String, message: String)?
    private lazy var settingsWindowController = SettingsWindowController(
        preferencesStore: preferencesStore,
        launchService: launchAtLoginService,
        onHotkeysChanged: { [weak self] in self?.reloadHotkeys() },
        registrationFailures: { [weak self] in self?.registrationFailureIdentifiers ?? [] },
        setHotkeysSuspended: { [weak self] suspended in self?.setHotkeysSuspended(suspended) },
        setMenuBarIconHidden: { [weak self] hidden in self?.statusBarController.setVisible(!hidden) },
        checkForUpdates: { [weak self] in self?.updaterController.checkForUpdates(nil) },
        requestNotificationAuthorization: { [weak self] in await self?.failureNotifier.requestAuthorization() ?? false }
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
                settings: #selector(openSettings(_:)),
                checkForUpdatesTarget: updaterController,
                checkForUpdates: #selector(SPUStandardUpdaterController.checkForUpdates(_:))
            )
        )
        statusBarController.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        statusBarController.checkForUpdates = (
            target: updaterController,
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        )
        statusBarController.lastFailureText = { [weak self] in
            guard let failure = self?.lastCommandFailure else { return nil }
            return "Last: \(failure.commandName) failed — \(failure.message)"
        }
        statusBarController.install()
        statusBarController.setVisible(!preferencesStore.menuBarIconHidden)
        reloadHotkeys()
        showSettingsOnFirstRunIfNeeded()

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
            lastCommandFailure = nil
        case .failure(.transient):
            // Space 전환·애니메이션 중 일시적 실패는 비프 없이 조용히 무시한다(메뉴 노출도 제외).
            Log.windows.debug("Hotkey \(command.displayName, privacy: .public) -> transient, skipped")
        case let .failure(error):
            lastCommandFailure = (command.displayName, error.userFacingMessage)
            if preferencesStore.soundFeedbackEnabled {
                NSSound.beep()
            }
            if preferencesStore.notifyOnCommandFailure {
                failureNotifier.postCommandFailure(commandName: command.displayName, message: error.userFacingMessage)
            }
            Log.windows.debug(
                "Hotkey \(command.displayName, privacy: .public) -> FAIL \(error.userFacingMessage, privacy: .public)"
            )
            nudgeForPermissionIfNeeded()
        }
    }

    /// 단축키가 "권한 미부여" 때문에 실패한 상황이면, 침묵의 beep 루프에 갇히지 않도록 세션당 1회
    /// Settings를 띄워 권한 안내로 연결한다(권한이 이미 있으면 다른 원인이므로 건드리지 않는다).
    private func nudgeForPermissionIfNeeded() {
        guard !didNudgeForPermissionThisSession,
              !AccessibilityPermissionService.currentStatus().isTrusted
        else { return }
        didNudgeForPermissionThisSession = true
        settingsWindowController.show()
        Log.app.debug("Hotkey failed without Accessibility permission — nudged to settings (once/session).")
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

    /// 첫 실행 온보딩: 권한 미부여 상태로 처음 켜지면 Settings 창을 자동으로 띄워 권한 안내
    /// (Permissions 카드 + "Open Accessibility Settings…")로 유도한다. 윈도우 매니저는 Accessibility
    /// 권한이 곧 제품 전체라, 메뉴바 아이콘만으로는 신규 사용자가 "작동 안 함"에 방치되기 쉽다.
    /// 이미 권한이 있으면 조용히 지나가고, 어느 경우든 1회만 수행한다(사용자가 끈 뒤 계속 뜨지 않게).
    /// DEBUG 빌드는 매 실행 Settings를 띄워 개발 편의를 유지한다.
    private func showSettingsOnFirstRunIfNeeded() {
        #if DEBUG
            settingsWindowController.show()
            Log.app.debug("Azimuth debug launch opened settings window.")
        #else
            guard !preferencesStore.didCompleteFirstRun else { return }
            preferencesStore.didCompleteFirstRun = true
            guard !AccessibilityPermissionService.currentStatus().isTrusted else { return }
            settingsWindowController.show()
            Log.app.debug("First run without Accessibility permission — opened settings for onboarding.")
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
