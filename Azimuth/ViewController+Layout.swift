//
//  ViewController+Layout.swift
//  Azimuth
//
//  설정창 레이아웃 구성(스크롤뷰·콘텐츠 스택)·폰트·서브뷰 팩토리. 본체는 ViewController,
//  @objc 액션은 ViewController+Actions에 둔다.
//

import Cocoa

extension ViewController {
    func configureView() {
        configureFonts()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStackView)
        scrollView.documentView = documentView
        view.addSubview(scrollView)

        shortcutsSectionView.widthAnchor.constraint(
            equalToConstant: Layout.shortcutsContentWidth
        ).isActive = true

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 문서 폭을 보이는 영역(clip view)에 맞춰 가로 스크롤을 막는다. 폭은 창에 고정되어 있다.
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStackView.leadingAnchor.constraint(
                equalTo: documentView.leadingAnchor, constant: Layout.contentInset
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: documentView.trailingAnchor, constant: -Layout.contentInset
            ),
            contentStackView.topAnchor.constraint(equalTo: documentView.topAnchor, constant: Layout.contentInset),
            contentStackView.bottomAnchor.constraint(
                equalTo: documentView.bottomAnchor, constant: -Layout.contentInset
            )
        ])
    }

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

    func makeContentStackView() -> NSStackView {
        let stackView = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            permissionsSection,
            shortcutsSection,
            behaviorSection,
            updatesSection
        ])
        stackView.alignment = .leading
        stackView.orientation = .vertical
        stackView.spacing = Layout.sectionSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }

    /// 권한 상태 아이콘(✓/⚠) + 상태 텍스트를 한 줄로 묶는다.
    func makePermissionStatusRow() -> NSStackView {
        statusIcon.imageScaling = .scaleProportionallyDown
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
