//
//  GeneralPaneViewController.swift
//  Azimuth
//
//  Created by hanyul on 3/31/26.
//
//  General 탭: 권한 상태 · 동작 설정 · 업데이트. 레이아웃 팩토리는 `GeneralPane+Layout`,
//  @objc 액션은 `GeneralPane+Actions`에 둔다(파일 비대화 방지, ShortcutsSectionView 규약).
//

import Cocoa

@MainActor
final class GeneralPaneViewController: NSViewController, SettingsPane {
    enum Layout {
        static let titleFontSize: CGFloat = 22
        static let statusFontSize: CGFloat = 13
    }

    let preferencesStore: PreferencesStore
    let launchService: LaunchAtLoginService
    let setMenuBarIconHidden: (Bool) -> Void
    /// "Check for Updates…" 버튼 액션. Sparkle 업데이터를 모르도록(결합 회피) 클로저로 받는다.
    let checkForUpdates: () -> Void
    /// 알림 권한 요청 결과. UserNotifications를 모르도록 클로저로 받는다 —
    /// "Notify when a command fails" 토글을 켜는 순간에만 불린다(opt-in).
    let requestNotificationAuthorization: () async -> NotificationAuthorizationResult

    init(
        preferencesStore: PreferencesStore,
        launchService: LaunchAtLoginService,
        setMenuBarIconHidden: @escaping (Bool) -> Void,
        checkForUpdates: @escaping () -> Void,
        requestNotificationAuthorization: @escaping () async -> NotificationAuthorizationResult
    ) {
        self.preferencesStore = preferencesStore
        self.launchService = launchService
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

    lazy var soundFeedbackButton = makeSoundFeedbackButton()
    lazy var notifyOnFailureButton = makeNotifyOnFailureButton()
    /// 알림 권한이 거부/실패라 토글을 켜지 못했을 때 System Settings로 안내하는 라벨
    /// (평소 숨김). launch-at-login의 승인 안내 라벨과 같은 패턴.
    let notifyApprovalLabel = NSTextField(wrappingLabelWithString: "")
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
    lazy var behaviorSection = SettingsCard.make(
        symbolName: "gearshape",
        title: "Behavior",
        bodyViews: [
            soundFeedbackButton,
            notifyOnFailureButton,
            notifyApprovalLabel,
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
    /// 스캐폴드가 설치한 스크롤 문서 뷰(자연 높이 측정용). 다른 페인과 같은 패턴.
    private var documentView: NSView?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: SettingsTabController.windowWidth, height: 640))
    }

    /// 콘텐츠 전체를 다 보여주기 위한 자연 높이(스크롤 없이 필요한 높이). 창 초기/최대 높이 산정에 쓴다.
    func naturalContentHeight() -> CGFloat {
        SettingsPaneScaffold.naturalContentHeight(of: documentView, in: view)
    }

    var paneTitle: String {
        "General"
    }

    var paneSymbolName: String {
        "gearshape"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureFonts()
        documentView = SettingsPaneScaffold.install(
            in: view, contentStack: SettingsPaneScaffold.makeContentStack(contentViews)
        )
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
        // 창을 다시 열거나 앱이 활성화될 때마다 이전에 띄운 알림 권한 안내를 정리한다
        // (사용자가 그새 System Settings에서 켜고 왔을 수 있어 stale 안내가 남지 않게 한다).
        notifyApprovalLabel.isHidden = true
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
