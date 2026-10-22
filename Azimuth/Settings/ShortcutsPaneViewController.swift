//
//  ShortcutsPaneViewController.swift
//  Azimuth
//
//  Shortcuts 탭: 프리셋 선택 + 검색 + 명령별 단축키 목록. 본문 뷰(ShortcutsSectionView)는
//  그대로 재사용하고 여기서는 호스팅과 갱신 시점만 맡는다.
//

import Cocoa

@MainActor
final class ShortcutsPaneViewController: NSViewController {
    /// 카드 내부 콘텐츠 폭. 컬럼 정렬이 흔들리지 않도록 고정한다(설정 창 상세 영역에 맞춘 값).
    private static let contentWidth: CGFloat = 480

    private let preferencesStore: PreferencesStore
    private let onHotkeysChanged: () -> Void
    private let registrationFailures: () -> Set<String>
    private let setHotkeysSuspended: (Bool) -> Void

    private let paneTitle = "Shortcuts"
    private let paneSymbolName = "keyboard"

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

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 560))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sectionView.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        let card = SettingsCard.make(symbolName: paneSymbolName, title: paneTitle, bodyViews: [sectionView])
        _ = SettingsPaneScaffold.install(in: view, contentStack: SettingsPaneScaffold.makeContentStack([card]))
    }

    /// 이 화면을 보일 때마다 그룹을 전부 접는다(상태 비저장). 화면은 스크롤 뷰 안에 있어 펼쳐도 창 크기는 그대로다.
    override func viewWillAppear() {
        super.viewWillAppear()
        sectionView.collapseAllGroups()
        sectionView.refresh()
    }
}
