//
//  ShortcutsPaneViewController.swift
//  Azimuth
//
//  Shortcuts 탭: 프리셋 선택 + 검색 + 명령별 단축키 목록. 본문 뷰(ShortcutsSectionView)는
//  그대로 재사용하고 여기서는 호스팅과 갱신 시점만 맡는다.
//

import Cocoa

@MainActor
final class ShortcutsPaneViewController: NSViewController, SettingsPane {
    /// 카드 내부 콘텐츠 폭. 컬럼 정렬이 흔들리지 않도록 고정한다(`SettingsTabController.windowWidth`에 맞춰 튜닝된 값).
    private static let contentWidth: CGFloat = 480

    private let preferencesStore: PreferencesStore
    private let onHotkeysChanged: () -> Void
    private let registrationFailures: () -> Set<String>
    private let setHotkeysSuspended: (Bool) -> Void

    var paneTitle: String {
        "Shortcuts"
    }

    var paneSymbolName: String {
        "keyboard"
    }

    init(
        preferencesStore: PreferencesStore,
        onHotkeysChanged: @escaping () -> Void,
        registrationFailures: @escaping () -> Set<String>,
        setHotkeysSuspended: @escaping (Bool) -> Void
    ) {
        self.preferencesStore = preferencesStore
        self.onHotkeysChanged = onHotkeysChanged
        self.registrationFailures = registrationFailures
        self.setHotkeysSuspended = setHotkeysSuspended
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private lazy var sectionView = ShortcutsSectionView(
        preferencesStore: preferencesStore,
        onHotkeysChanged: onHotkeysChanged,
        registrationFailures: registrationFailures,
        setHotkeysSuspended: setHotkeysSuspended
    )
    private var documentView: NSView?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: SettingsTabController.windowWidth, height: 560))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sectionView.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        let card = SettingsCard.make(symbolName: paneSymbolName, title: paneTitle, bodyViews: [sectionView])
        documentView = SettingsPaneScaffold.install(
            in: view, contentStack: SettingsPaneScaffold.makeContentStack([card])
        )
        sectionView.onExpansionChanged = { [weak self] in self?.fitWindowToContent() }
    }

    /// 창을 열거나 이 탭으로 올 때마다 그룹을 전부 접는다(상태 비저장 — 창 높이 예측 가능).
    /// 접은 뒤 창 높이를 다시 맞춰, 닫을 때 펼쳐 둔 키 큰 창이 접힌 내용 아래 빈 공간을 남기지 않게 한다.
    override func viewWillAppear() {
        super.viewWillAppear()
        sectionView.collapseAllGroups()
        sectionView.refresh()
        fitWindowToContent()
    }

    /// 콘텐츠 높이가 바뀌면 창 높이를 다시 맞춘다. 탭 전환과 같은 경로(`resizeWindowToSelectedPane`)를
    /// 타야 최대 높이 상한도 함께 갱신된다 — 상한이 접힌 높이에 묶인 채면 펼친 그룹을 창을 늘려 볼 수 없다.
    /// 컨테이너는 AppKit 뷰 컨트롤러 포함 관계(`parent`)로 얻는다.
    private func fitWindowToContent() {
        (parent as? SettingsTabController)?.resizeWindowToSelectedPane()
    }

    func naturalContentHeight() -> CGFloat {
        SettingsPaneScaffold.naturalContentHeight(of: documentView, in: view)
    }
}
