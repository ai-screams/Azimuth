//
//  GeneralPane+Layout.swift
//  Azimuth
//
//  General 탭 폰트·서브뷰 팩토리. 스크롤뷰·콘텐츠 스택은 SettingsPaneScaffold, 본체는 GeneralPaneViewController,
//  @objc 액션은 GeneralPane+Actions에 둔다.
//

import Cocoa

extension GeneralPaneViewController {
    func configureFonts() {
        titleLabel.font = .systemFont(ofSize: Layout.titleFontSize, weight: .semibold)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 0

        statusLabel.font = .systemFont(ofSize: Layout.statusFontSize, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 0

        launchApprovalLabel.textColor = .systemOrange
        launchApprovalLabel.font = .systemFont(ofSize: Layout.statusFontSize)
        launchApprovalLabel.maximumNumberOfLines = 0
        notifyApprovalLabel.textColor = .systemOrange
        notifyApprovalLabel.font = .systemFont(ofSize: Layout.statusFontSize)
        notifyApprovalLabel.maximumNumberOfLines = 0
        notifyApprovalLabel.isHidden = true
        menuBarIconHintLabel.textColor = .secondaryLabelColor
        menuBarIconHintLabel.font = .systemFont(ofSize: Layout.statusFontSize)
        menuBarIconHintLabel.maximumNumberOfLines = 0

        versionLabel.textColor = .secondaryLabelColor
        versionLabel.font = .systemFont(ofSize: Layout.statusFontSize)
        versionLabel.stringValue = bundleVersionString()
    }

    /// 번들에서 표시 버전을 읽는다(About 창과 동일 규칙 — Bundle.displayVersion 공용).
    private func bundleVersionString() -> String {
        Bundle.main.displayVersion(prefix: "Azimuth")
    }

    /// 스크롤 문서에 위에서부터 쌓을 콘텐츠. 스택·스크롤뷰 구성은 `SettingsPaneScaffold`가 한다.
    var contentViews: [NSView] {
        [titleLabel, subtitleLabel, permissionsSection, behaviorSection, updatesSection]
    }

    /// 권한 상태 아이콘(✓/⚠) + 상태 텍스트를 한 줄로 묶는다.
    func makePermissionStatusRow() -> NSStackView {
        statusIcon.imageScaling = .scaleProportionallyDown
        statusIcon.setAccessibilityElement(false) // 장식용 — 권한 상태는 statusLabel 텍스트가 전달한다
        statusIcon.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [statusIcon, statusLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        NSLayoutConstraint.activate([
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
        return row
    }

    func makeActionButton() -> NSButton {
        .rounded(title: "Open Accessibility Settings…", target: self, action: #selector(openAccessibilitySettings(_:)))
    }

    func makeSoundFeedbackButton() -> NSButton {
        NSButton(
            checkboxWithTitle: "Play a sound when a command can't run",
            target: self,
            action: #selector(soundFeedbackChanged(_:))
        )
    }

    func makeNotifyOnFailureButton() -> NSButton {
        NSButton(
            checkboxWithTitle: "Notify when a command fails",
            target: self,
            action: #selector(notifyOnFailureChanged(_:))
        )
    }

    func makeMenuBarIconButton() -> NSButton {
        NSButton(
            checkboxWithTitle: "Hide menu bar icon",
            target: self,
            action: #selector(menuBarIconChanged(_:))
        )
    }

    func makeLaunchAtLoginButton() -> NSButton {
        NSButton(
            checkboxWithTitle: "Launch Azimuth at login",
            target: self,
            action: #selector(launchAtLoginChanged(_:))
        )
    }

    func makeLaunchApprovalButton() -> NSButton {
        .rounded(title: "Open Login Items Settings…", target: self, action: #selector(openLoginItemsSettings(_:)))
    }

    func makeCheckForUpdatesButton() -> NSButton {
        .rounded(title: "Check for Updates…", target: self, action: #selector(checkForUpdatesClicked(_:)))
    }
}
