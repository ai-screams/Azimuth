//
//  ViewController+Actions.swift
//  Azimuth
//
//  설정창 @objc 액션 핸들러(권한·사운드·메뉴바 아이콘·로그인 항목). UI 구성은 ViewController+Layout,
//  상태 갱신(updatePermissionUI/updateBehaviorUI)은 ViewController 본체에 둔다.
//

import Cocoa
import os

extension ViewController {
    @objc func openAccessibilitySettings(_ sender: Any?) {
        _ = AccessibilityPermissionService.requestPrompt()

        guard AccessibilityPermissionService.openSystemSettings() else {
            NSSound.beep()
            return
        }
    }

    @objc func handleDidBecomeActive(_ notification: Notification) {
        updatePermissionUI()
        updateBehaviorUI()
    }

    @objc func soundFeedbackChanged(_ sender: NSButton) {
        preferencesStore.soundFeedbackEnabled = sender.state == .on
    }

    /// 알림 권한은 토글을 켜는 순간에만 요청한다(opt-in). 거부되면(최초 거부든 시스템 설정의
    /// 기존 거부든) 토글을 되돌려 "켜져 보이는데 알림이 안 오는" 상태를 만들지 않는다.
    @objc func notifyOnFailureChanged(_ sender: NSButton) {
        guard sender.state == .on else {
            preferencesStore.notifyOnCommandFailure = false
            return
        }
        Task { @MainActor in
            if await requestNotificationAuthorization() {
                preferencesStore.notifyOnCommandFailure = true
            } else {
                sender.state = .off
                preferencesStore.notifyOnCommandFailure = false
                NSSound.beep()
                Log.app.info("Notification permission denied — notify-on-failure toggle reverted.")
            }
        }
    }

    @objc func menuBarIconChanged(_ sender: NSButton) {
        let hidden = sender.state == .on
        preferencesStore.menuBarIconHidden = hidden
        setMenuBarIconHidden(hidden)
    }

    @objc func launchAtLoginChanged(_ sender: NSButton) {
        if sender.state == .on {
            do {
                try launchService.enable()
            } catch {
                if preferencesStore.soundFeedbackEnabled {
                    NSSound.beep()
                }
                Log.app.error("Failed to register login item: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            launchService.disable { [weak self] in self?.updateBehaviorUI() }
        }
        updateBehaviorUI()
    }

    @objc func openLoginItemsSettings(_ sender: Any?) {
        launchService.openSystemSettingsLoginItems()
    }

    @objc func checkForUpdatesClicked(_ sender: Any?) {
        checkForUpdates()
    }
}
