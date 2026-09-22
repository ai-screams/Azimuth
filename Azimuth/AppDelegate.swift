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
    private let windowSnapStore = SnapStateStore()
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
        setResolveTimeout: { seconds in FocusedWindowResolver.setResolveTimeout(seconds) },
        checkForUpdates: { [weak self] in self?.updaterController.checkForUpdates(nil) },
        requestNotificationAuthorization: { [weak self] in
            await self?.failureNotifier.requestAuthorization() ?? .failed
        }
    )
    private lazy var statusBarController = StatusBarController(
        frontmostAppTracker: frontmostAppTracker,
        windowUndoStore: windowUndoStore,
        windowSnapStore: windowSnapStore
    )
    private let firstRunGuidePresenter = FirstRunGuidePresenter()

    /// 기동 순서. 각 단계가 무엇인지 이름으로 읽히도록 블록별로 나눠 두었다 —
    /// **순서가 의미를 갖는다**: 메뉴·상태바가 있어야 온보딩 팝오버가 앵커할 곳이 생기고,
    /// 해석 상한을 반영한 뒤여야 첫 단축키가 올바른 상한으로 돈다.
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureActivationPolicy()
        installMainMenu()
        installStatusBar()
        // 고급 설정의 해석 상한을 기동 시 한 번 반영한다(setter 가 다시 클램프하므로 이중 안전).
        FocusedWindowResolver.setResolveTimeout(preferencesStore.resolveTimeout)
        reloadHotkeys()
        showFirstRunOnboardingIfNeeded()
        registerAppObservers()
        // DEBUG에서 설정창을 띄웠을 수 있으니 현재 창 상태에 맞춰 정책을 한 번 동기화한다.
        updateActivationPolicy()
    }

    /// 표준 메인 메뉴(App·Edit·Window). 없으면 ⌘Q·⌘W·텍스트 편집이 어디서도 처리되지 않아
    /// 경고음만 난다(.accessory 빌드도 키 equivalent는 동작한다).
    private func installMainMenu() {
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
    }

    /// 메뉴바 항목과 그 메뉴가 앱에 되묻는 세 경로(설정 열기·업데이트 확인·마지막 실패 사유).
    /// 클로저로 주입하는 이유는 `StatusBarController`가 Sparkle과 앱 상태를 모르게 하기 위해서다.
    private func installStatusBar() {
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
    }

    /// 앱 수명 동안 유지되는 알림 구독. 해제는 `deinit`의 `removeObserver(self)`가 한꺼번에 한다.
    private func registerAppObservers() {
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
        let result = WindowCommandExecutor.run(
            command, tracker: frontmostAppTracker, undoStore: windowUndoStore, snapStore: windowSnapStore
        )
        let error = result.commandError
        let feedback = CommandFeedbackPolicy.decide(
            error: error,
            soundEnabled: preferencesStore.soundFeedbackEnabled,
            notifyEnabled: preferencesStore.notifyOnCommandFailure,
            alreadyNudgedThisSession: didNudgeForPermissionThisSession
        )
        apply(feedback, for: command)
        logOutcome(error, for: command)
    }

    /// 정책이 내린 결정을 실행만 한다. 판단은 `CommandFeedbackPolicy`가 이미 끝냈다.
    private func apply(_ feedback: CommandFeedback, for command: WindowCommand) {
        switch feedback.lastFailure {
        case .clear:
            lastCommandFailure = nil
        case .keep:
            break
        case let .set(message):
            lastCommandFailure = (command.displayName, message)
        }
        if feedback.beep {
            NSSound.beep()
        }
        // 알림 문구는 **정책이 준 값**에서 읽는다. `lastCommandFailure`를 읽어도 오늘은 맞지만
        // (`notify`가 참인 경우는 항상 `.set` 직후라) 그 안전이 두 필드의 우연한 합의에 기댄다 —
        // `.keep`과 `notify`가 함께 참이 되는 조합이 생기면 **지난 실패 문구가 새 알림으로** 나간다.
        if feedback.notify, case let .set(message) = feedback.lastFailure {
            failureNotifier.postCommandFailure(commandName: command.displayName, message: message)
        }
        if feedback.nudgeForPermission {
            nudgeForPermission()
        }
    }

    /// 조용한 스킵과 실패는 진단 가치가 달라 로그를 구분해 남긴다(정책이 아니라 부수효과라 여기 둔다).
    private func logOutcome(_ error: WindowCommandError?, for command: WindowCommand) {
        guard let error else { return }
        if error == .transient {
            Log.windows.debug("Hotkey \(command.displayName, privacy: .public) -> transient, skipped")
        } else {
            Log.windows.debug(
                "Hotkey \(command.displayName, privacy: .public) -> FAIL \(error.userFacingMessage, privacy: .public)"
            )
        }
    }

    /// 권한 미부여로 단축키가 실패했을 때 세션당 1회 Settings를 띄워 안내로 연결한다.
    ///
    /// "권한이 없는가"는 여기서 **다시 조회하지 않는다** — `CommandFeedbackPolicy`가 에러를 보고 이미
    /// 판정했다. 예전에는 이 자리에서 `currentStatus()`를 읽었는데, 그 캐시는 앱 활성화·메뉴 열기에서만
    /// 무효화되고 이 함수가 도는 순간은 정확히 그 둘 다 일어나지 않은 때라, 실행 중 권한이 풀린 경우
    /// 낡은 `true`를 읽고 안내를 건너뛰었다 — 막으려던 침묵의 beep 루프가 그대로 일어났다.
    private func nudgeForPermission() {
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
        // 디스플레이 연결/해제·배치 변경 시 저장된 절대 frame은 무효 → undo 이력과 스냅 상태를 버린다.
        windowUndoStore.clearAll()
        windowSnapStore.clearAll()
        Log.windows.debug("Screen parameters changed; cleared window undo history and snap state.")
    }

    /// 첫 실행 온보딩: 상태바 아이콘에 앵커한 안내 팝오버로 메뉴바 상주·전역 단축키를 소개한다.
    /// 윈도우 매니저는 Accessibility 권한이 곧 제품 전체라, 권한 미부여면 기본 버튼이
    /// "Open Settings…"가 되어 Settings의 Permissions 카드로 연결한다.
    /// 플래그는 표시 "결정" 시점에 기록해(닫힘 시점이 아니라) 크래시 시 재표시 루프를 막고,
    /// 상태 아이템이 메뉴바에 자리잡도록 0.6초 뒤에 띄운다. 상태바 버튼을 얻지 못하면(슬롯 부족 등)
    /// 기존 폴백대로 권한 미부여 시 Settings 창을 연다. 어느 경우든 1회만 수행한다.
    /// DEBUG 빌드는 매 실행 Settings를 띄우는 개발 편의를 유지한다(팝오버는 플래그를 따름).
    private func showFirstRunOnboardingIfNeeded() {
        #if DEBUG
            settingsWindowController.show()
            Log.app.debug("Azimuth debug launch opened settings window.")
        #endif
        guard !preferencesStore.didCompleteFirstRun else { return }
        preferencesStore.didCompleteFirstRun = true
        let needsPermission = !AccessibilityPermissionService.currentStatus().isTrusted
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            guard let button = statusBarController.statusButton, !preferencesStore.menuBarIconHidden else {
                if needsPermission {
                    settingsWindowController.show()
                    Log.app.debug("First run without a status item — opened settings for onboarding.")
                }
                return
            }
            firstRunGuidePresenter.show(
                relativeTo: button,
                launchService: launchAtLoginService,
                needsPermission: needsPermission,
                onOpenSettings: { [weak self] in self?.settingsWindowController.show() }
            )
            Log.app.debug("First-run guide popover shown.")
        }
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
