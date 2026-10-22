//
//  SettingsModel.swift
//  Azimuth
//
//  설정 창 SwiftUI 화면의 얇은 모델. 값의 주인은 `PreferencesStore`·권한 서비스·로그인 항목 서비스이고,
//  모델은 화면에 보일 값을 들고 있다가 같은 시점(창 표시, 앱 활성화)에 다시 읽는다.
//  판단이 필요한 곳은 순수 로직을 쓴다(`BoundedIntSetting`, `NotifyToggleDecision`, `ResolveTimeoutChoice`).
//

import AppKit
import Observation
import os

/// 설정 창이 바깥에서 받는 것. 화면이 Sparkle·UserNotifications·WindowAccess를 직접 모르도록 클로저로 받는다.
struct SettingsDependencies {
    let preferencesStore: PreferencesStore
    let launchService: LaunchAtLoginService
    let onHotkeysChanged: () -> Void
    let registrationFailures: () -> Set<String>
    let setHotkeysSuspended: (Bool) -> Void
    let setMenuBarIconHidden: (Bool) -> Void
    let setResolveTimeout: (Float) -> Void
    let checkForUpdates: () -> Void
    let requestNotificationAuthorization: () async -> NotificationAuthorizationResult
}

@Observable
final class SettingsModel {
    enum Pane: String, CaseIterable, Identifiable {
        case general
        case shortcuts
        case advanced
        case about

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .general:
                "General"
            case .shortcuts:
                "Shortcuts"
            case .advanced:
                "Advanced"
            case .about:
                "About"
            }
        }

        var symbol: String {
            switch self {
            case .general:
                "gearshape"
            case .shortcuts:
                "keyboard"
            case .advanced:
                "slider.horizontal.3"
            case .about:
                "info.circle"
            }
        }
    }

    @ObservationIgnored let dependencies: SettingsDependencies
    var selection: Pane? = .general

    private(set) var permission = AccessibilityPermissionStatus.required
    private(set) var soundFeedback = false
    private(set) var notifyOnFailure = false
    private(set) var showsNotifyHint = false
    private(set) var launchAtLogin = false
    private(set) var launchNeedsApproval = false
    private(set) var menuBarIconHidden = false
    private(set) var undoDepth = UndoHistory.depth.defaultValue
    private(set) var undoWindowCapacity = UndoHistory.windowCapacity.defaultValue
    private(set) var resolveTimeout = ResolveTimeoutChoice.balanced
    /// Sparkle이 지금 확인을 받을 수 있는지. AppDelegate가 업데이터를 관찰해 넣는다.
    var canCheckForUpdates = true

    private var store: PreferencesStore {
        dependencies.preferencesStore
    }

    init(dependencies: SettingsDependencies) {
        self.dependencies = dependencies
        refresh()
    }

    /// 창을 보일 때와 앱이 다시 활성화될 때. 사용자가 그사이 System Settings에서 권한·로그인 항목·알림을
    /// 바꿨을 수 있다. 로그인 항목(SMAppService)은 변경 알림이 없어 이렇게 다시 읽을 수밖에 없다.
    func refresh() {
        permission = AccessibilityPermissionService.currentStatus()
        soundFeedback = store.soundFeedbackEnabled
        notifyOnFailure = store.notifyOnCommandFailure
        showsNotifyHint = false // 그새 켜고 왔을 수 있어 지난 안내를 남기지 않는다
        launchAtLogin = dependencies.launchService.isEnabled
        launchNeedsApproval = dependencies.launchService.requiresApproval
        menuBarIconHidden = store.menuBarIconHidden
        undoDepth = store.undoDepth
        undoWindowCapacity = store.undoWindowCapacity
        resolveTimeout = ResolveTimeoutChoice.nearest(toSeconds: store.resolveTimeout)
    }

    /// 앱 활성화 시. 권한 캐시는 AppDelegate도 비우지만 관찰자 순서가 보장되지 않아 여기서도 비운다.
    func appDidBecomeActive() {
        AccessibilityPermissionService.invalidateCache()
        refresh()
    }

    // MARK: - General

    func requestAccessibility() {
        if !AccessibilityPermissionService.requestAccess(preferences: store) { NSSound.beep() }
    }

    func setSoundFeedback(_ on: Bool) {
        store.soundFeedbackEnabled = on
        soundFeedback = on
    }

    /// 켤 때만 알림 권한을 요청한다(opt-in). 결과에 따른 저장·토글·안내는 `NotifyToggleDecision`이 정한다.
    func setNotifyOnFailure(_ on: Bool) {
        notifyOnFailure = on
        guard on else {
            store.notifyOnCommandFailure = false
            showsNotifyHint = false
            return
        }
        Task { @MainActor in
            let result = await dependencies.requestNotificationAuthorization()
            let outcome = NotifyToggleDecision.afterRequest(result, toggleStillOn: notifyOnFailure)
            store.notifyOnCommandFailure = outcome.stored
            notifyOnFailure = outcome.toggleOn
            showsNotifyHint = outcome.showsSettingsHint
            if result != .granted {
                Log.app.info("Notification permission not granted — notify-on-failure toggle reverted.")
            }
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        if on {
            do {
                try dependencies.launchService.enable()
            } catch {
                if store.soundFeedbackEnabled { NSSound.beep() }
                Log.app.error("Failed to register login item: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            dependencies.launchService.disable { [weak self] in self?.refresh() }
        }
        refresh()
    }

    func openLoginItemsSettings() {
        dependencies.launchService.openSystemSettingsLoginItems()
    }

    func setMenuBarIconHidden(_ hidden: Bool) {
        store.menuBarIconHidden = hidden
        menuBarIconHidden = hidden
        dependencies.setMenuBarIconHidden(hidden)
    }

    // MARK: - Advanced

    /// 입력 칸의 글자. 숫자가 아니면 저장하지 않고 화면이 저장된 값으로 되돌린다(`BoundedIntSetting.parse`).
    func commitUndoDepth(_ text: String) {
        if let value = UndoHistory.depth.parse(text) { setUndoDepth(value) } else { undoDepth = store.undoDepth }
    }

    func setUndoDepth(_ value: Int) {
        store.undoDepth = value // 저장은 PreferencesStore가 클램프한다
        undoDepth = store.undoDepth
    }

    func commitUndoWindowCapacity(_ text: String) {
        if let value = UndoHistory.windowCapacity.parse(text) {
            setUndoWindowCapacity(value)
        } else {
            undoWindowCapacity = store.undoWindowCapacity
        }
    }

    func setUndoWindowCapacity(_ value: Int) {
        store.undoWindowCapacity = value
        undoWindowCapacity = store.undoWindowCapacity
    }

    /// 저장은 PreferencesStore가 클램프하고, 실행 중인 앱에는 바로 반영한다(다음 명령부터).
    func setResolveTimeout(_ choice: ResolveTimeoutChoice) {
        store.resolveTimeout = choice.seconds
        resolveTimeout = choice
        dependencies.setResolveTimeout(store.resolveTimeout)
        Log.app.info("Resolve timeout set to \(choice.rawValue, privacy: .public)")
    }

    // MARK: - About

    var versionText: String {
        Bundle.main.displayVersion(prefix: "Version")
    }

    func checkForUpdates() {
        dependencies.checkForUpdates()
    }
}
