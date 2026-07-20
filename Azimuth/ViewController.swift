//
//  ViewController.swift
//  Azimuth
//
//  Created by hanyul on 3/31/26.
//
//  설정창 본체: 프로퍼티·생명주기·상태 갱신. 레이아웃 구성과 팩토리는 `ViewController+Layout`,
//  @objc 액션 핸들러는 `ViewController+Actions`에 분리한다(파일 비대화 방지, ShortcutsSectionView 규약).
//

import Cocoa

@MainActor
final class ViewController: NSViewController {
    enum Layout {
        static let windowSize = NSSize(width: 560, height: 640)
        static let shortcutsContentWidth: CGFloat = 480
        static let contentInset: CGFloat = 24
        static let sectionSpacing: CGFloat = 16
        static let titleFontSize: CGFloat = 22
        static let statusFontSize: CGFloat = 13
    }

    let preferencesStore: PreferencesStore
    let launchService: LaunchAtLoginService
    private let onHotkeysChanged: () -> Void
    private let registrationFailures: () -> Set<String>
    private let setHotkeysSuspended: (Bool) -> Void
    let setMenuBarIconHidden: (Bool) -> Void
    /// "Check for Updates…" 버튼 액션. Sparkle 업데이터를 모르도록(결합 회피) 클로저로 받는다.
    let checkForUpdates: () -> Void
    /// 알림 권한 요청(true = 허용). UserNotifications를 모르도록 클로저로 받는다 —
    /// "Notify when a command fails" 토글을 켜는 순간에만 불린다(opt-in).
    let requestNotificationAuthorization: () async -> Bool

    init(
        preferencesStore: PreferencesStore,
        launchService: LaunchAtLoginService,
        onHotkeysChanged: @escaping () -> Void,
        registrationFailures: @escaping () -> Set<String>,
        setHotkeysSuspended: @escaping (Bool) -> Void,
        setMenuBarIconHidden: @escaping (Bool) -> Void,
        checkForUpdates: @escaping () -> Void,
        requestNotificationAuthorization: @escaping () async -> Bool
    ) {
        self.preferencesStore = preferencesStore
        self.launchService = launchService
        self.onHotkeysChanged = onHotkeysChanged
        self.registrationFailures = registrationFailures
        self.setHotkeysSuspended = setHotkeysSuspended
        self.setMenuBarIconHidden = setMenuBarIconHidden
        self.checkForUpdates = checkForUpdates
        self.requestNotificationAuthorization = requestNotificationAuthorization
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    let titleLabel = NSTextField(labelWithString: "Azimuth Settings")
    let subtitleLabel = NSTextField(
        wrappingLabelWithString: "Configure Azimuth's shortcuts, feedback, and launch behavior."
    )

    let statusIcon = NSImageView()
    let statusLabel = NSTextField(labelWithString: "")
    let detailLabel = NSTextField(wrappingLabelWithString: "")
    lazy var actionButton = makeActionButton()
    lazy var permissionStatusRow = makePermissionStatusRow()

    lazy var shortcutsSectionView = ShortcutsSectionView(
        preferencesStore: preferencesStore,
        onHotkeysChanged: onHotkeysChanged,
        registrationFailures: registrationFailures,
        setHotkeysSuspended: setHotkeysSuspended
    )

    lazy var soundFeedbackButton = makeSoundFeedbackButton()
    lazy var notifyOnFailureButton = makeNotifyOnFailureButton()
    lazy var launchAtLoginButton = makeLaunchAtLoginButton()
    let launchApprovalLabel = NSTextField(wrappingLabelWithString: "")
    lazy var launchApprovalButton = makeLaunchApprovalButton()
    lazy var menuBarIconButton = makeMenuBarIconButton()
    let menuBarIconHintLabel = NSTextField(
        wrappingLabelWithString: "When hidden, open Azimuth again from Finder or Spotlight to reopen this window."
    )

    let versionLabel = NSTextField(labelWithString: "")
    lazy var checkForUpdatesButton = makeCheckForUpdatesButton()

    lazy var permissionsSection = SettingsCard.make(
        symbolName: "lock.shield",
        title: "Permissions",
        bodyViews: [permissionStatusRow, detailLabel, actionButton]
    )
    lazy var shortcutsSection = SettingsCard.make(
        symbolName: "keyboard",
        title: "Shortcuts",
        bodyViews: [shortcutsSectionView]
    )
    lazy var behaviorSection = SettingsCard.make(
        symbolName: "gearshape",
        title: "Behavior",
        bodyViews: [
            soundFeedbackButton,
            notifyOnFailureButton,
            launchAtLoginButton,
            launchApprovalLabel,
            launchApprovalButton,
            menuBarIconButton,
            menuBarIconHintLabel
        ]
    )
    lazy var updatesSection = SettingsCard.make(
        symbolName: "arrow.triangle.2.circlepath",
        title: "Updates",
        bodyViews: [versionLabel, checkForUpdatesButton]
    )
    lazy var contentStackView = makeContentStackView()

    /// 모든 콘텐츠를 담는 바깥 세로 스크롤뷰. 창을 콘텐츠보다 낮게 줄여도 하단 섹션이
    /// 잘리지 않고 스크롤된다(폭은 창에 고정되어 가로 스크롤은 발생하지 않는다).
    let scrollView = NSScrollView()
    /// 스크롤 문서 뷰. 위에서부터 콘텐츠가 채워지도록 뒤집힌(flipped) 좌표계를 쓴다.
    let documentView = FlippedView()

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

    func updatePermissionUI() {
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
    func updateBehaviorUI() {
        soundFeedbackButton.state = preferencesStore.soundFeedbackEnabled ? .on : .off
        notifyOnFailureButton.state = preferencesStore.notifyOnCommandFailure ? .on : .off
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
