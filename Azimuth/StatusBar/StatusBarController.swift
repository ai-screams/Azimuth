import Cocoa
import os

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    var onOpenSettings: (() -> Void)?
    /// "Practice Shortcuts…": 연습 창 안내를 다시 연다(#176).
    var onPracticeShortcuts: (() -> Void)?
    /// "Open Accessibility Settings" 동작. 성공(알림 요청 또는 설정 열기)이면 true — 실패면 이 컨트롤러가 알린다.
    /// 권한 알림 시도 기록(`PreferencesStore`)을 모르게 하려고 AppDelegate가 주입한다.
    var onRequestAccessibility: (() -> Bool)?
    /// Sparkle 업데이터의 (타깃, 셀렉터). install() 전에 설정하면 메뉴에 "Check for Updates…"가 추가된다.
    /// Sparkle import를 StatusBarController로 끌어오지 않으려고 제네릭 타깃/셀렉터로 받는다.
    var checkForUpdates: (target: AnyObject, action: Selector)?
    /// 마지막 명령 실패의 표시 문구(nil이면 행 숨김). AppDelegate가 주입한다 —
    /// "beep만 나고 이유를 알 수 없는" 실패를 메뉴를 열면 설명하기 위한 행이다.
    var lastFailureText: (() -> String?)?
    /// 팝오버 타일이 명령을 실행하는 경로. 단축키와 같은 경로라 실패 비프·사유·알림이 똑같이 붙는다.
    var runCommand: ((WindowCommand) -> Void)?
    /// 팝오버 아래 줄 키캡. 연습 창과 같은 "실제로 등록된 단축키".
    var boundShortcut: ((WindowCommand) -> HotkeyShortcut?)?
    /// 팝오버를 열기 직전. 같은 버튼에 붙은 첫 실행 안내 팝오버를 닫아 둘이 겹치지 않게 한다.
    var willShowPopover: (() -> Void)?

    private var statusItem: NSStatusItem?
    /// 왼쪽 클릭이 여는 팝오버(#178). `install()`에서 주입된 클로저로 만든다.
    private var popover: StatusPopoverController?
    /// 오른쪽 클릭·Control-클릭이 여는 메뉴. 평소에는 상태 항목에 붙여 두지 않는다(붙어 있으면 버튼 동작이 오지 않는다).
    private lazy var statusMenu = makeStatusMenu()
    private let permissionStatusMenuItem = NSMenuItem()
    /// 마지막 명령 실패 사유(정보 행). 실패가 없으면 숨겨지고, menuWillOpen에서 갱신된다.
    private let lastFailureMenuItem: NSMenuItem = {
        let item = NSMenuItem()
        item.isEnabled = false
        item.isHidden = true
        item.image = NSImage(
            systemSymbolName: "exclamationmark.triangle",
            accessibilityDescription: "Last command failed"
        )
        return item
    }()

    private let openAccessibilitySettingsMenuItem = NSMenuItem(
        title: "Open Accessibility Settings…",
        action: #selector(openAccessibilitySettings(_:)),
        keyEquivalent: ""
    )
    private let frontmostAppTracker: FrontmostAppTracker
    private let windowUndoStore: WindowUndoStore
    private let windowSnapStore: SnapStateStore
    #if DEBUG
        private let debugResolutionMenuItem = NSMenuItem()
        private let designGallery = DesignGalleryWindowController()
    #endif

    init(
        frontmostAppTracker: FrontmostAppTracker,
        windowUndoStore: WindowUndoStore,
        windowSnapStore: SnapStateStore
    ) {
        self.frontmostAppTracker = frontmostAppTracker
        self.windowUndoStore = windowUndoStore
        self.windowSnapStore = windowSnapStore
        super.init()
    }

    func install() {
        popover = makePopover()
        configureStatusItem()
        refreshPermissionState()
    }

    /// 메뉴바 상태 아이콘 표시/숨김. 숨겨도 Azimuth를 다시 실행하면 설정창이 열린다(접근 경로 보존).
    func setVisible(_ visible: Bool) {
        if !visible { popover?.close() }
        statusItem?.isVisible = visible
    }

    /// Sparkle이 확인을 받을 수 있는지. 메뉴 항목은 Sparkle이 스스로 검사하지만 팝오버 단추는 여기서 받는다.
    func setCanCheckForUpdates(_ canCheck: Bool) {
        popover?.model.canCheckForUpdates = canCheck
    }

    /// 첫 실행 가이드 팝오버의 앵커용 상태바 버튼. 시스템이 메뉴바 슬롯을 주지 않으면 nil.
    var statusButton: NSStatusBarButton? {
        statusItem?.button
    }

    func refreshPermissionState() {
        let status = AccessibilityPermissionService.currentStatus()
        permissionStatusMenuItem.title = status.menuTitle
        openAccessibilitySettingsMenuItem.isHidden = status.isTrusted
        updateStatusButton(isTrusted: status.isTrusted)
    }

    private func updateStatusButton(isTrusted: Bool) {
        guard let button = statusItem?.button else { return }
        button.image = StatusBarIcon.image(needsPermission: !isTrusted)
        button.toolTip = isTrusted ? "Azimuth" : "Azimuth needs Accessibility access"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshBeforeOpening()
        updateLastFailureItem()
        #if DEBUG
            updateDebugResolutionMenuItem()
        #endif
    }

    /// 메뉴는 열릴 때만 붙여 둔다. 닫히면 떼어야 다음 왼쪽 클릭이 다시 팝오버로 간다.
    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
    }

    /// .accessory 앱은 메뉴나 팝오버를 열어도 활성화(didBecomeActive) 알림이 늘 오지는 않아 권한 캐시가 그대로다.
    /// System Settings에서 방금 토글한 상태가 보이도록 열 때마다 캐시를 비운다(가끔 여는 동기 tccd 호출 1회는
    /// 캐시 목적 — 핫키마다 호출 방지 — 와 충돌하지 않는다).
    private func refreshBeforeOpening() {
        AccessibilityPermissionService.invalidateCache()
        refreshPermissionState()
    }

    /// 마지막 명령이 실패했으면 그 사유를, 성공/없음이면 행을 숨긴다(메뉴 열 때마다 갱신).
    private func updateLastFailureItem() {
        if let text = lastFailureText?() {
            lastFailureMenuItem.title = text
            lastFailureMenuItem.isHidden = false
        } else {
            lastFailureMenuItem.isHidden = true
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // 메뉴바 슬롯을 일관되게 유지하고, 콘텐츠를 먼저 채운 뒤 표시한다.
        item.autosaveName = "Azimuth"
        statusItem = item
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusButton(isTrusted: AccessibilityPermissionService.currentStatus().isTrusted)
        item.isVisible = true
        Log.app.debug("Azimuth status item created.")
    }

    /// 메뉴 구성은 세 구획으로 나눈다 — 권한 상태(진단), DEBUG 전용 도구, 일반 앱 동작.
    /// 한 함수에 모으면 항목을 하나 추가할 때마다 function_body_length 한계(60)에 부딪힌다.
    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        addPermissionSection(to: menu)
        menu.addItem(.separator())
        addDebugSection(to: menu)
        addAppSection(to: menu)
        return menu
    }

    /// 권한 상태 행과 그 조치(설정 열기), 마지막 명령 실패 사유 행.
    private func addPermissionSection(to menu: NSMenu) {
        permissionStatusMenuItem.isEnabled = false
        menu.addItem(permissionStatusMenuItem)

        openAccessibilitySettingsMenuItem.target = self
        menu.addItem(openAccessibilitySettingsMenuItem)

        menu.addItem(lastFailureMenuItem)
    }

    /// DEBUG 빌드 전용 진단 항목. Release에서는 통째로 사라지므로 구분선도 여기서 함께 붙인다.
    private func addDebugSection(to menu: NSMenu) {
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

            menu.addItem(makeDebugCommandsItem())

            let galleryItem = NSMenuItem(
                title: "Design Gallery (Debug)",
                action: #selector(openDesignGalleryDebug(_:)),
                keyEquivalent: ""
            )
            galleryItem.target = self
            menu.addItem(galleryItem)
            menu.addItem(.separator())
        #endif
    }

    #if DEBUG
        /// `menuCommands` 전체를 서브메뉴로 나열한다. tag가 곧 배열 인덱스(핸들러가 역조회에 쓴다).
        private func makeDebugCommandsItem() -> NSMenuItem {
            let commandsItem = NSMenuItem(title: "Window Commands (Debug)", action: nil, keyEquivalent: "")
            let commandsSubmenu = NSMenu()
            for (index, command) in WindowCommand.menuCommands.enumerated() {
                let item = NSMenuItem(
                    title: command.displayName,
                    action: #selector(runWindowCommandDebug(_:)),
                    keyEquivalent: ""
                )
                item.tag = index
                item.target = self
                commandsSubmenu.addItem(item)
            }
            commandsItem.submenu = commandsSubmenu
            return commandsItem
        }
    #endif

    /// 설정·업데이트·종료 — 일반 사용자에게 노출되는 앱 동작.
    private func addAppSection(to menu: NSMenu) {
        let settingsItem = NSMenuItem(
            title: "Open Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let practiceItem = NSMenuItem(
            title: "Practice Shortcuts…",
            action: #selector(practiceShortcuts(_:)),
            keyEquivalent: ""
        )
        practiceItem.target = self
        menu.addItem(practiceItem)

        if let checkForUpdates {
            let updatesItem = NSMenuItem(
                title: "Check for Updates…",
                action: checkForUpdates.action,
                keyEquivalent: ""
            )
            updatesItem.target = checkForUpdates.target
            menu.addItem(updatesItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Azimuth",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openSettings(_ sender: Any?) {
        onOpenSettings?()
    }

    @objc private func practiceShortcuts(_ sender: Any?) {
        onPracticeShortcuts?()
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        // 주입이 빠졌어도(nil) 조용히 넘어가지 않고 실패로 알린다.
        guard onRequestAccessibility?() == true else {
            NSSound.beep()
            return
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}

/// 왼쪽 클릭 팝오버와 오른쪽 클릭 메뉴(#178).
extension StatusBarController {
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let action = StatusClickPolicy.action(
            isRightClick: event?.type == .rightMouseUp,
            isControlDown: event?.modifierFlags.contains(.control) == true,
            popoverShown: popover?.isShown == true
        )
        switch action {
        case .showPopover:
            refreshBeforeOpening()
            willShowPopover?()
            popover?.show(relativeTo: sender)
        case .closePopover:
            popover?.close()
        case .showMenu:
            popover?.close()
            statusItem?.menu = statusMenu
            sender.performClick(nil)
        }
    }

    /// 팝오버가 앱에 되묻는 경로. 이미 주입된 클로저를 그대로 넘겨 앱 상태를 두 곳에서 들고 있지 않는다.
    private func makePopover() -> StatusPopoverController {
        let updates = checkForUpdates
        let dependencies = StatusPopoverDependencies(
            run: { [weak self] command in self?.runCommand?(command) },
            shortcut: { [weak self] command in self?.boundShortcut?(command) },
            isTrusted: { AccessibilityPermissionService.currentStatus().isTrusted },
            lastFailure: { [weak self] in self?.lastFailureText?() },
            openSettings: { [weak self] in self?.onOpenSettings?() },
            requestAccessibility: { [weak self] in self?.openAccessibilitySettings(nil) },
            checkForUpdates: {
                guard let updates else { return }
                NSApp.sendAction(updates.action, to: updates.target, from: nil)
            },
            quit: { NSApp.terminate(nil) },
            close: { [weak self] in self?.popover?.close() },
            closeForWindow: { [weak self] in self?.popover?.close(openedWindow: true) }
        )
        let tracker = frontmostAppTracker
        return StatusPopoverController(dependencies: dependencies) { tracker.targetApplication }
    }
}

#if DEBUG
    extension StatusBarController {
        @objc private func openDesignGalleryDebug(_ sender: Any?) {
            designGallery.show()
        }

        @objc private func identifyFocusedWindowDebug(_ sender: Any?) {
            let text = currentResolutionText()
            Log.windows.debug("[P3] menu -> \(text, privacy: .public)")

            let alert = NSAlert()
            alert.messageText = "Focused Window (Debug)"
            alert.informativeText = text
            alert.runModal()
        }

        private func updateDebugResolutionMenuItem() {
            debugResolutionMenuItem.title = "Focused: \(currentResolutionText())"
        }

        @objc private func runWindowCommandDebug(_ sender: NSMenuItem) {
            let commands = WindowCommand.menuCommands
            guard sender.tag >= 0, sender.tag < commands.count else { return }
            let command = commands[sender.tag]

            let result = WindowCommandExecutor.run(
                command,
                tracker: frontmostAppTracker,
                undoStore: windowUndoStore,
                snapStore: windowSnapStore
            )
            switch result {
            case let .success(frame):
                let rect = NSStringFromRect(frame)
                Log.windows.debug(
                    "[P5] \(command.displayName, privacy: .public) -> OK AX \(rect, privacy: .public)"
                )
            case let .failure(error):
                let msg = error.userFacingMessage
                Log.windows.debug(
                    "[P5] \(command.displayName, privacy: .public) -> FAIL \(msg, privacy: .public)"
                )
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
