//
//  ViewController.swift
//  Yuri
//
//  Created by hanyul on 3/31/26.
//

import Cocoa
import os

@MainActor
final class ViewController: NSViewController {
    private enum Layout {
        static let windowSize = NSSize(width: 560, height: 420)
        static let contentInset: CGFloat = 24
        static let sectionSpacing: CGFloat = 16
        static let sectionContentSpacing: CGFloat = 8
        static let sectionPadding: CGFloat = 16
        static let sectionCornerRadius: CGFloat = 10
        static let sectionBorderWidth: CGFloat = 1
        static let minSectionWidth: CGFloat = 512
        static let titleFontSize: CGFloat = 22
        static let sectionTitleFontSize: CGFloat = 15
        static let statusFontSize: CGFloat = 13
    }

    private let preferencesStore: PreferencesStore
    private let launchService: LaunchAtLoginService
    private let onPresetChange: () -> Void

    init(
        preferencesStore: PreferencesStore,
        launchService: LaunchAtLoginService,
        onPresetChange: @escaping () -> Void
    ) {
        self.preferencesStore = preferencesStore
        self.launchService = launchService
        self.onPresetChange = onPresetChange
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private let titleLabel = NSTextField(labelWithString: "Yuri Settings")
    private let subtitleLabel = NSTextField(
        wrappingLabelWithString: "Configure Yuri's shortcuts, feedback, and launch behavior."
    )

    private let permissionsTitleLabel = NSTextField(labelWithString: "Permissions")
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var actionButton = makeActionButton()

    private let shortcutsTitleLabel = NSTextField(labelWithString: "Shortcuts")
    private let presetCaptionLabel = NSTextField(labelWithString: "Keymap preset")
    private lazy var presetPopUp = makePresetPopUp()
    private let presetHintLabel = NSTextField(
        wrappingLabelWithString: "Standard uses arrow keys; Vim swaps to H/J/K/L for halves, moves, and resizes."
    )

    private let behaviorTitleLabel = NSTextField(labelWithString: "Behavior")
    private lazy var soundFeedbackButton = makeSoundFeedbackButton()
    private lazy var launchAtLoginButton = makeLaunchAtLoginButton()
    private let launchApprovalLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var launchApprovalButton = makeLaunchApprovalButton()

    private lazy var permissionsSection = makeSection(
        titleLabel: permissionsTitleLabel,
        bodyViews: [statusLabel, detailLabel, actionButton]
    )
    private lazy var shortcutsSection = makeSection(
        titleLabel: shortcutsTitleLabel,
        bodyViews: [presetCaptionLabel, presetPopUp, presetHintLabel]
    )
    private lazy var behaviorSection = makeSection(
        titleLabel: behaviorTitleLabel,
        bodyViews: [soundFeedbackButton, launchAtLoginButton, launchApprovalLabel, launchApprovalButton]
    )
    private lazy var contentStackView = makeContentStackView()

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Layout.windowSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        updatePermissionUI()
        updateBehaviorUI()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updatePermissionUI()
        updateBehaviorUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        _ = AccessibilityPermissionService.requestPrompt()

        guard AccessibilityPermissionService.openSystemSettings() else {
            NSSound.beep()
            return
        }
    }

    @objc private func handleDidBecomeActive(_ notification: Notification) {
        updatePermissionUI()
        updateBehaviorUI()
    }

    @objc private func presetChanged(_ sender: NSPopUpButton) {
        guard let preset = sender.selectedItem?.representedObject as? HotkeyPreset else { return }
        preferencesStore.activePreset = preset
        onPresetChange()
    }

    @objc private func soundFeedbackChanged(_ sender: NSButton) {
        preferencesStore.soundFeedbackEnabled = sender.state == .on
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
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

    @objc private func openLoginItemsSettings(_ sender: Any?) {
        launchService.openSystemSettingsLoginItems()
    }

    private func configureView() {
        configureFonts()
        view.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.contentInset),
            contentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Layout.contentInset),
            contentStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: Layout.contentInset),
            contentStackView.bottomAnchor.constraint(
                lessThanOrEqualTo: view.bottomAnchor,
                constant: -Layout.contentInset
            )
        ])
    }

    private func configureFonts() {
        titleLabel.font = .systemFont(ofSize: Layout.titleFontSize, weight: .semibold)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 0

        permissionsTitleLabel.font = .systemFont(ofSize: Layout.sectionTitleFontSize, weight: .semibold)
        statusLabel.font = .systemFont(ofSize: Layout.statusFontSize, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 0

        shortcutsTitleLabel.font = .systemFont(ofSize: Layout.sectionTitleFontSize, weight: .semibold)
        presetCaptionLabel.font = .systemFont(ofSize: Layout.statusFontSize, weight: .medium)
        presetHintLabel.textColor = .secondaryLabelColor
        presetHintLabel.maximumNumberOfLines = 0

        behaviorTitleLabel.font = .systemFont(ofSize: Layout.sectionTitleFontSize, weight: .semibold)
        launchApprovalLabel.textColor = .systemOrange
        launchApprovalLabel.font = .systemFont(ofSize: Layout.statusFontSize)
        launchApprovalLabel.maximumNumberOfLines = 0
    }

    private func updatePermissionUI() {
        let status = AccessibilityPermissionService.currentStatus()

        statusLabel.stringValue = status.settingsStatusText
        statusLabel.textColor = status.isTrusted ? .systemGreen : .systemOrange
        detailLabel.stringValue = status.settingsDetailText
        actionButton.isHidden = status.isTrusted
    }

    /// SMAppService는 상태 변경 알림(KVO/Notification)을 제공하지 않으므로, 로그인 항목 상태는
    /// 화면 표시·앱 활성화(didBecomeActive) 시점에 폴링해 갱신한다. 설정창이 떠 있는 채로
    /// System Settings에서 토글하면 다시 활성화될 때까지 갱신이 지연될 수 있다.
    private func updateBehaviorUI() {
        soundFeedbackButton.state = preferencesStore.soundFeedbackEnabled ? .on : .off
        launchAtLoginButton.state = launchService.isEnabled ? .on : .off

        let needsApproval = launchService.requiresApproval
        launchApprovalLabel.isHidden = !needsApproval
        launchApprovalButton.isHidden = !needsApproval
        if needsApproval {
            launchApprovalLabel.stringValue =
                "Login item is registered but needs approval in System Settings > General > Login Items."
        }
    }

    private func makePresetPopUp() -> NSPopUpButton {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        // 각 항목에 프리셋을 representedObject로 묶어 위치(index) 의존을 피한다.
        for preset in HotkeyPreset.allCases {
            popUp.addItem(withTitle: preset.displayName)
            popUp.lastItem?.representedObject = preset
        }
        if let index = HotkeyPreset.allCases.firstIndex(of: preferencesStore.activePreset) {
            popUp.selectItem(at: index)
        }
        popUp.target = self
        popUp.action = #selector(presetChanged(_:))
        return popUp
    }

    private func makeSoundFeedbackButton() -> NSButton {
        NSButton(
            checkboxWithTitle: "Play a sound when a command can't run",
            target: self,
            action: #selector(soundFeedbackChanged(_:))
        )
    }

    private func makeLaunchAtLoginButton() -> NSButton {
        NSButton(
            checkboxWithTitle: "Launch Yuri at login",
            target: self,
            action: #selector(launchAtLoginChanged(_:))
        )
    }

    private func makeLaunchApprovalButton() -> NSButton {
        let button = NSButton(
            title: "Open Login Items Settings…",
            target: self,
            action: #selector(openLoginItemsSettings(_:))
        )
        button.bezelStyle = .rounded
        return button
    }
}

private extension ViewController {
    func makeActionButton() -> NSButton {
        let button = NSButton(
            title: "Open Accessibility Settings…",
            target: self,
            action: #selector(openAccessibilitySettings(_:))
        )
        button.bezelStyle = .rounded
        return button
    }

    func makeContentStackView() -> NSStackView {
        let stackView = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            permissionsSection,
            shortcutsSection,
            behaviorSection
        ])
        stackView.alignment = .leading
        stackView.orientation = .vertical
        stackView.spacing = Layout.sectionSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }

    func makeSection(titleLabel: NSTextField, bodyViews: [NSView]) -> NSBox {
        let stackView = NSStackView(views: [titleLabel] + bodyViews)
        stackView.alignment = .leading
        stackView.orientation = .vertical
        stackView.spacing = Layout.sectionContentSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(
            top: Layout.sectionPadding,
            left: Layout.sectionPadding,
            bottom: Layout.sectionPadding,
            right: Layout.sectionPadding
        )

        let box = NSBox()
        box.boxType = .custom
        box.borderType = .lineBorder
        box.cornerRadius = Layout.sectionCornerRadius
        box.borderWidth = Layout.sectionBorderWidth
        box.borderColor = .separatorColor
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stackView)

        if let contentView = box.contentView {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                box.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.minSectionWidth)
            ])
        }

        return box
    }
}
