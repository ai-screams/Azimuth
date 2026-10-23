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
    /// 첫 접근(`installMainMenu`)에서 만들어지며 그때 업데이터가 시작된다.
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: updateVersionDisplayer
    )
    /// 업데이트 창의 버전을 "v1.7.2"로 표시한다. Sparkle은 delegate를 약하게 잡으므로 여기서 보유한다.
    private let updateVersionDisplayer = UpdateVersionDisplayer()
    private let frontmostAppTracker = FrontmostAppTracker()
    /// 깊이와 창 수는 설정에서 읽어 온다(#170) — 설정 화면이 이 저장소를 몰라도 되고, 바꾸면 다음 명령부터 반영된다.
    private lazy var windowUndoStore = WindowUndoStore(
        depth: { [preferencesStore] in preferencesStore.undoDepth },
        windowCapacity: { [preferencesStore] in preferencesStore.undoWindowCapacity }
    )
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
    /// 설정 창에서 단축키를 녹화하는 중. 치트시트도 함께 멈춘다(녹화 조합을 누르고 있을 때 뜨지 않게).
    private var hotkeysSuspended = false
    /// 가장 최근 단축키 명령이 실패했을 때의 (명령 이름, 사유). 상태바 메뉴에 노출해
    /// "beep만 나는" 실패의 이유를 설명한다. 다음 명령이 성공하면 지운다(세션 한정, 저장 안 함).
    private var lastCommandFailure: (commandName: String, message: String)?
    private lazy var settingsWindowController = SettingsWindowController(dependencies: SettingsDependencies(
        preferencesStore: preferencesStore,
        launchService: launchAtLoginService,
        onHotkeysChanged: { [weak self] in self?.reloadHotkeys() },
        registrationFailures: { [weak self] in self?.registrationFailureIdentifiers ?? [] },
        setHotkeysSuspended: { [weak self] suspended in self?.setHotkeysSuspended(suspended) },
        setMenuBarIconHidden: { [weak self] hidden in self?.statusBarController.setVisible(!hidden) },
        setResolveTimeout: { seconds in FocusedWindowResolver.setResolveTimeout(seconds) },
        checkForUpdates: { [weak self] in self?.updaterController.checkForUpdates(nil) },
        showPracticeGuide: { [weak self] in self?.practiceWindowController.show() },
        onPermissionGranted: { [weak self] in
            self?.statusBarController.refreshPermissionState()
            self?.updateCheatSheet()
        },
        onCheatSheetChanged: { [weak self] in self?.updateCheatSheet() },
        requestNotificationAuthorization: { [weak self] in
            await self?.failureNotifier.requestAuthorization() ?? .failed
        }
    ))
    /// 설정 창 "Check for Updates…" 버튼의 활성 상태. SwiftUI 버튼은 메뉴 항목처럼 자동 검증되지 않아,
    /// Sparkle의 `canCheckForUpdates`(KVO 지원)를 관찰해 넣는다(`observeUpdateAvailability`).
    private var canCheckForUpdatesObservation: NSKeyValueObservation?
    private lazy var statusBarController = StatusBarController(
        frontmostAppTracker: frontmostAppTracker,
        windowUndoStore: windowUndoStore,
        windowSnapStore: windowSnapStore
    )
    private let firstRunGuidePresenter = FirstRunGuidePresenter()
    /// 연습 창 안내(#176). 연습 창이 앞에 있을 때의 단축키는 명령 실행기 대신 여기로 간다(`runCommand`).
    private lazy var practiceWindowController = PracticeWindowController(
        shortcut: { [weak self] command in self?.boundShortcut(for: command) },
        soundEnabled: { [weak self] in self?.preferencesStore.soundFeedbackEnabled ?? false }
    )
    /// 수정키를 누르고 있으면 뜨는 단축키 치트시트(#182). 실제로 등록된 바인딩만 그린다.
    private lazy var cheatSheetController = CheatSheetController { [weak self] in self?.registeredBindings() ?? [] }

    /// 기동 순서. 각 단계가 무엇인지 이름으로 읽히도록 블록별로 나눠 두었다 —
    /// **순서가 의미를 갖는다**: 메뉴·상태바가 있어야 온보딩 팝오버가 앵커할 곳이 생기고,
    /// 해석 상한을 반영한 뒤여야 첫 단축키가 올바른 상한으로 돈다.
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureActivationPolicy()
        installMainMenu()
        canCheckForUpdatesObservation = observeUpdateAvailability()
        installStatusBar()
        // 고급 설정의 해석 상한을 기동 시 한 번 반영한다(setter 가 다시 클램프하므로 이중 안전).
        FocusedWindowResolver.setResolveTimeout(preferencesStore.resolveTimeout)
        reloadHotkeys()
        updateCheatSheet()
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

    /// App 메뉴 "About Azimuth" 항목 액션. 별도 About 창 없이 설정 창의 About 화면을 연다(#176).
    @objc private func showAboutPanel(_ sender: Any?) {
        settingsWindowController.show(pane: .about)
    }

    /// App 메뉴 "Settings…"(⌘,) 항목 액션.
    @objc private func openSettings(_ sender: Any?) {
        settingsWindowController.show()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func reloadHotkeys() {
        let failed = hotkeyService.reload(enabledBindings()) { [weak self] command in
            self?.runCommand(command)
        }
        registrationFailureIdentifiers = Set(failed.map(\.command.identifier))
    }

    /// 단축키 녹화 중에는 전역 핫키를 모두 해제하고, 끝나면 다시 등록한다(녹화 조합의 오발화 방지).
    private func setHotkeysSuspended(_ suspended: Bool) {
        hotkeysSuspended = suspended
        updateCheatSheet()
        if suspended {
            hotkeyService.unregisterAll()
        } else {
            reloadHotkeys()
        }
    }

    /// 단축키와 메뉴바 팝오버 타일이 같이 쓰는 실행 경로.
    private func runCommand(_ command: WindowCommand) {
        cheatSheetController.commandRan()
        // 연습 창이 앞에 있으면 연습 창이 받는다(자기 창은 AX 명령 대상이 아니다).
        if practiceWindowController.handle(command) { return }
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
        updateCheatSheet()
    }

    /// 치트시트 감시를 켤지: 설정이 켜져 있고, 권한이 있고(없으면 전역 키 이벤트가 오지 않는다), 녹화 중이 아닐 때.
    /// 권한이 생기면 이 함수로 감시를 새로 건다.
    private func updateCheatSheet() {
        let active = preferencesStore.cheatSheetEnabled
            && AccessibilityPermissionService.currentStatus().isTrusted
            && !hotkeysSuspended
        cheatSheetController.setActive(active, delay: preferencesStore.cheatSheetDelay)
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
                    settingsWindowController.show(pane: .general)
                    Log.app.debug("First run without a status item — opened settings for onboarding.")
                }
                return
            }
            firstRunGuidePresenter.show(
                relativeTo: button,
                launchService: launchAtLoginService,
                needsPermission: needsPermission,
                onOpenSettings: { [weak self] in self?.settingsWindowController.show(pane: .general) },
                onTryShortcuts: { [weak self] in self?.practiceWindowController.show() }
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

extension AppDelegate {
    /// 메뉴바 항목과 그 메뉴가 앱에 되묻는 세 경로(설정 열기·업데이트 확인·마지막 실패 사유).
    /// 클로저로 주입하는 이유는 `StatusBarController`가 Sparkle과 앱 상태를 모르게 하기 위해서다.
    private func installStatusBar() {
        statusBarController.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        statusBarController.onPracticeShortcuts = { [weak self] in
            self?.practiceWindowController.show()
        }
        statusBarController.onRequestAccessibility = { [weak self] in
            guard let self else { return false }
            return AccessibilityPermissionService.requestAccess(preferences: preferencesStore)
        }
        statusBarController.checkForUpdates = (
            target: updaterController,
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        )
        statusBarController.lastFailureText = { [weak self] in
            guard let failure = self?.lastCommandFailure else { return nil }
            return "Last: \(failure.commandName) failed — \(failure.message)"
        }
        statusBarController.runCommand = { [weak self] command in self?.runCommand(command) }
        statusBarController.boundShortcut = { [weak self] command in self?.boundShortcut(for: command) }
        statusBarController.willShowPopover = { [weak self] in self?.firstRunGuidePresenter.close() }
        statusBarController.install()
        statusBarController.setVisible(!preferencesStore.menuBarIconHidden)
    }

    /// 등록할 바인딩: 프리셋 + 사용자 지정에서 꺼진 명령과 그룹을 뺀 것. 등록(`reloadHotkeys`)과 연습 창이 같이 쓴다.
    private func enabledBindings() -> [HotkeyBinding] {
        let resolved = BindingResolver.resolve(
            preset: preferencesStore.activePreset,
            overrides: preferencesStore.customShortcuts
        )
        return BindingResolver.enabled(
            resolved,
            disabledCommands: preferencesStore.disabledCommandIdentifiers,
            disabledGroups: preferencesStore.disabledGroupTokens
        )
    }

    /// 실제로 눌러서 오는 바인딩: 켜진 것 중 등록에 실패하지 않은 것(다른 앱이 쓰는 조합은 눌러도 오지 않는다).
    /// 연습 창·팝오버 키캡과 치트시트가 같이 쓴다.
    private func registeredBindings() -> [HotkeyBinding] {
        enabledBindings().filter { !registrationFailureIdentifiers.contains($0.command.identifier) }
    }

    private func boundShortcut(for command: WindowCommand) -> HotkeyShortcut? {
        registeredBindings().first { $0.command == command }?.shortcut
    }

    /// Sparkle이 확인을 받을 수 있는지를 설정 창에 계속 알린다. 업데이터가 시작된 뒤(`installMainMenu`) 부른다.
    private func observeUpdateAvailability() -> NSKeyValueObservation {
        updaterController.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            DispatchQueue.main.async {
                self?.settingsWindowController.setCanCheckForUpdates(canCheck)
                self?.statusBarController.setCanCheckForUpdates(canCheck)
            }
        }
    }
}
