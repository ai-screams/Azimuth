import Cocoa
import os

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    var onOpenSettings: (() -> Void)?
    /// Sparkle 업데이터의 (타깃, 셀렉터). install() 전에 설정하면 메뉴에 "Check for Updates…"가 추가된다.
    /// Sparkle import를 StatusBarController로 끌어오지 않으려고 제네릭 타깃/셀렉터로 받는다.
    var checkForUpdates: (target: AnyObject, action: Selector)?

    private var statusItem: NSStatusItem?
    private let permissionStatusMenuItem = NSMenuItem()
    private let openAccessibilitySettingsMenuItem = NSMenuItem(
        title: "Open Accessibility Settings…",
        action: #selector(openAccessibilitySettings(_:)),
        keyEquivalent: ""
    )
    private let frontmostAppTracker: FrontmostAppTracker
    private let windowUndoStore: WindowUndoStore
    #if DEBUG
        private let debugResolutionMenuItem = NSMenuItem()
    #endif

    init(frontmostAppTracker: FrontmostAppTracker, windowUndoStore: WindowUndoStore) {
        self.frontmostAppTracker = frontmostAppTracker
        self.windowUndoStore = windowUndoStore
        super.init()
    }

    func install() {
        configureStatusItem()
        refreshPermissionState()
        #if DEBUG
            configureDebugWindowProbe()
        #endif
    }

    /// 메뉴바 상태 아이콘 표시/숨김. 숨겨도 Azimuth를 다시 실행하면 설정창이 열린다(접근 경로 보존).
    func setVisible(_ visible: Bool) {
        statusItem?.isVisible = visible
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
        let symbol = isTrusted ? "macwindow.on.rectangle" : "exclamationmark.triangle"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Azimuth")
        image?.isTemplate = true
        button.image = image
        button.toolTip = isTrusted ? "Azimuth" : "Azimuth needs Accessibility access"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshPermissionState()
        #if DEBUG
            updateDebugResolutionMenuItem()
        #endif
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // 메뉴바 슬롯을 일관되게 유지하고, 콘텐츠를 먼저 채운 뒤 표시한다.
        item.autosaveName = "Azimuth"
        item.menu = makeStatusMenu()
        statusItem = item
        updateStatusButton(isTrusted: AccessibilityPermissionService.currentStatus().isTrusted)
        item.isVisible = true
        Log.app.debug("Azimuth status item created.")
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
            menu.addItem(commandsItem)
            menu.addItem(.separator())
        #endif

        let settingsItem = NSMenuItem(
            title: "Open Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

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

        return menu
    }

    @objc private func openSettings(_ sender: Any?) {
        onOpenSettings?()
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        _ = AccessibilityPermissionService.requestPrompt()
        guard AccessibilityPermissionService.openSystemSettings() else {
            NSSound.beep()
            return
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}

#if DEBUG
    extension StatusBarController {
        private func configureDebugWindowProbe() {
            frontmostAppTracker.onChange = { [weak self] _ in
                guard let self else { return }
                Log.windows.debug("[P3] activate -> \(self.currentResolutionText(), privacy: .public)")
            }
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
                undoStore: windowUndoStore
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
