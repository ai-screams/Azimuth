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

    /// 알림 권한은 토글을 켜는 순간에만 요청한다(opt-in). 켜지 못하면 토글을 되돌려
    /// "켜져 보이는데 알림이 안 오는" 상태를 막고, 거부/실패는 (beep 없이) System Settings
    /// 안내 라벨로 연결한다 — 사용자가 의도적으로 누른 체크박스에 beep은 잘못된 신호다.
    @objc func notifyOnFailureChanged(_ sender: NSButton) {
        guard sender.state == .on else {
            preferencesStore.notifyOnCommandFailure = false
            notifyApprovalLabel.isHidden = true
            return
        }
        Task { @MainActor in
            let result = await requestNotificationAuthorization()
            // 권한 프롬프트를 기다리는 사이 사용자가 토글을 껐다면 그 의사를 존중한다
            // (안 그러면 체크는 꺼져 보이는데 알림은 켜지는 어긋남이 생긴다).
            guard sender.state == .on else {
                preferencesStore.notifyOnCommandFailure = false
                return
            }
            switch result {
            case .granted:
                preferencesStore.notifyOnCommandFailure = true
                notifyApprovalLabel.isHidden = true
            case .denied:
                sender.state = .off
                preferencesStore.notifyOnCommandFailure = false
                notifyApprovalLabel.stringValue =
                    "Enable notifications for Azimuth in System Settings > Notifications, then try again."
                notifyApprovalLabel.isHidden = false
                Log.app.info("Notification permission denied — notify-on-failure toggle reverted.")
            case .failed:
                // 요청 자체 에러(예: DerivedData 개발 빌드는 알림 미등록). 이 경우 앱이
                // System Settings에 나타나지도 않으므로 그 안내는 오히려 막다른 길 → 라벨은 숨기고
                // 로그만 남긴다(사실상 개발 빌드 전용 경로).
                sender.state = .off
                preferencesStore.notifyOnCommandFailure = false
                notifyApprovalLabel.isHidden = true
                Log.app.error("Notification request failed — notify-on-failure toggle reverted.")
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
