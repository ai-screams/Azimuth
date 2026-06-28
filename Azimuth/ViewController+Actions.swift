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
}
