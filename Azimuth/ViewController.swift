//
//  ViewController.swift
//  Azimuth
//
//  Created by hanyul on 3/31/26.
//

import Cocoa
import os

@MainActor
final class ViewController: NSViewController {
    private enum Layout {
        static let windowSize = NSSize(width: 560, height: 640)
        static let shortcutsContentWidth: CGFloat = 480
        static let contentInset: CGFloat = 24
        static let sectionSpacing: CGFloat = 16
        static let titleFontSize: CGFloat = 22
        static let statusFontSize: CGFloat = 13
    }

    private let preferencesStore: PreferencesStore
    private let launchService: LaunchAtLoginService
    private let onHotkeysChanged: () -> Void
    private let registrationFailures: () -> Set<String>
    private let setHotkeysSuspended: (Bool) -> Void
    private let setMenuBarIconHidden: (Bool) -> Void

    init(
        preferencesStore: PreferencesStore,
        launchService: LaunchAtLoginService,
        onHotkeysChanged: @escaping () -> Void,
        registrationFailures: @escaping () -> Set<String>,
        setHotkeysSuspended: @escaping (Bool) -> Void,
        setMenuBarIconHidden: @escaping (Bool) -> Void
    ) {
        self.preferencesStore = preferencesStore
        self.launchService = launchService
        self.onHotkeysChanged = onHotkeysChanged
        self.registrationFailures = registrationFailures
        self.setHotkeysSuspended = setHotkeysSuspended
        self.setMenuBarIconHidden = setMenuBarIconHidden
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private let titleLabel = NSTextField(labelWithString: "Azimuth Settings")
    private let subtitleLabel = NSTextField(
        wrappingLabelWithString: "Configure Azimuth's shortcuts, feedback, and launch behavior."
    )

    private let statusIcon = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var actionButton = makeActionButton()
    private lazy var permissionStatusRow = makePermissionStatusRow()

    private lazy var shortcutsSectionView = ShortcutsSectionView(
        preferencesStore: preferencesStore,
        onHotkeysChanged: onHotkeysChanged,
        registrationFailures: registrationFailures,
        setHotkeysSuspended: setHotkeysSuspended
    )

    private lazy var soundFeedbackButton = makeSoundFeedbackButton()
    private lazy var launchAtLoginButton = makeLaunchAtLoginButton()
    private let launchApprovalLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var launchApprovalButton = makeLaunchApprovalButton()
    private lazy var menuBarIconButton = makeMenuBarIconButton()
    private let menuBarIconHintLabel = NSTextField(
        wrappingLabelWithString: "When hidden, relaunch Azimuth to reopen this settings window."
    )

    private lazy var permissionsSection = SettingsCard.make(
        symbolName: "lock.shield",
        title: "Permissions",
        bodyViews: [permissionStatusRow, detailLabel, actionButton]
    )
    private lazy var shortcutsSection = SettingsCard.make(
        symbolName: "keyboard",
        title: "Shortcuts",
        bodyViews: [shortcutsSectionView]
    )
    private lazy var behaviorSection = SettingsCard.make(
        symbolName: "gearshape",
        title: "Behavior",
        bodyViews: [
            soundFeedbackButton,
            launchAtLoginButton,
            launchApprovalLabel,
            launchApprovalButton,
            menuBarIconButton,
            menuBarIconHintLabel
        ]
    )
    private lazy var contentStackView = makeContentStackView()

    /// 모든 콘텐츠를 담는 바깥 세로 스크롤뷰. 창을 콘텐츠보다 낮게 줄여도 하단 섹션이
    /// 잘리지 않고 스크롤된다(폭은 창에 고정되어 가로 스크롤은 발생하지 않는다).
    private let scrollView = NSScrollView()
    /// 스크롤 문서 뷰. 위에서부터 콘텐츠가 채워지도록 뒤집힌(flipped) 좌표계를 쓴다.
    private let documentView = FlippedView()

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Layout.windowSize))
    }

    /// 콘텐츠 전체를 다 보여주기 위한 자연 높이(스크롤 없이 필요한 높이). 창 초기/최대 높이 산정에 쓴다.
    func naturalContentHeight() -> CGFloat {
        view.layoutSubtreeIfNeeded()
        return documentView.frame.height
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
        shortcutsSectionView.refresh()
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

    @objc private func soundFeedbackChanged(_ sender: NSButton) {
        preferencesStore.soundFeedbackEnabled = sender.state == .on
    }

    @objc private func menuBarIconChanged(_ sender: NSButton) {
        let hidden = sender.state == .on
        preferencesStore.menuBarIconHidden = hidden
        setMenuBarIconHidden(hidden)
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

    private func configureFonts() {
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
    }

    private func updatePermissionUI() {
        let status = AccessibilityPermissionService.currentStatus()

        statusLabel.stringValue = status.settingsStatusText
        statusLabel.textColor = status.isTrusted ? .systemGreen : .systemOrange
        detailLabel.stringValue = status.settingsDetailText
        actionButton.isHidden = status.isTrusted

        let symbol = status.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        statusIcon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        statusIcon.contentTintColor = status.isTrusted ? .systemGreen : .systemOrange
    }

    /// SMAppService는 상태 변경 알림(KVO/Notification)을 제공하지 않으므로, 로그인 항목 상태는
    /// 화면 표시·앱 활성화(didBecomeActive) 시점에 폴링해 갱신한다. 설정창이 떠 있는 채로
    /// System Settings에서 토글하면 다시 활성화될 때까지 갱신이 지연될 수 있다.
    private func updateBehaviorUI() {
        soundFeedbackButton.state = preferencesStore.soundFeedbackEnabled ? .on : .off
        menuBarIconButton.state = preferencesStore.menuBarIconHidden ? .on : .off
        launchAtLoginButton.state = launchService.isEnabled ? .on : .off

        let needsApproval = launchService.requiresApproval
        launchApprovalLabel.isHidden = !needsApproval
        launchApprovalButton.isHidden = !needsApproval
        if needsApproval {
            launchApprovalLabel.stringValue =
                "Login item is registered but needs approval in System Settings > General > Login Items."
        }
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
        let button = NSButton(
            title: "Open Login Items Settings…",
            target: self,
            action: #selector(openLoginItemsSettings(_:))
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
}

/// 위에서부터 콘텐츠가 쌓이도록 뒤집힌 좌표계를 쓰는 스크롤 문서 뷰.
/// (기본 NSView는 원점이 좌하단이라 스크롤뷰 콘텐츠가 아래에서부터 쌓여 어색하다.)
private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
