//
//  AdvancedPaneViewController.swift
//  Azimuth
//
//  Advanced 탭: AX 해석 상한 조정. 일반 사용자가 건드릴 필요가 없는 항목을 별도 탭으로
//  분리해, "여기는 안 와도 된다"는 신호가 구조로 드러나게 한다.
//

import Cocoa
import os

@MainActor
final class AdvancedPaneViewController: NSViewController, SettingsPane {
    private let preferencesStore: PreferencesStore
    /// 변경을 실행 중인 앱에 즉시 반영한다. 페인이 WindowAccess를 직접 건드리지 않도록 클로저로 받는다.
    private let setResolveTimeout: (Float) -> Void

    var paneTitle: String {
        "Advanced"
    }

    var paneSymbolName: String {
        "slider.horizontal.3"
    }

    init(preferencesStore: PreferencesStore, setResolveTimeout: @escaping (Float) -> Void) {
        self.preferencesStore = preferencesStore
        self.setResolveTimeout = setResolveTimeout
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private lazy var resolveTimeoutPopUp = makeResolveTimeoutPopUp()
    private let hintLabel = NSTextField(wrappingLabelWithString:
        "Shorter keeps Azimuth's menus responsive when an app hangs. "
            + "Longer gives slow apps more time to answer. Leave this alone unless commands "
            + "fail on apps that are merely slow.")
    private var documentView: NSView?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 240))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.maximumNumberOfLines = 0

        let card = SettingsCard.make(
            symbolName: paneSymbolName,
            title: paneTitle,
            bodyViews: [makeResolveTimeoutRow(), hintLabel]
        )
        documentView = SettingsPaneScaffold.install(
            in: view, contentStack: SettingsPaneScaffold.makeContentStack([card])
        )
        refresh()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    func naturalContentHeight() -> CGFloat {
        view.layoutSubtreeIfNeeded()
        return documentView?.frame.height ?? 0
    }

    /// 저장된 값에 가장 가까운 선택지를 고른다(defaults가 손으로 편집됐어도 항상 하나).
    private func refresh() {
        let choice = ResolveTimeoutChoice.nearest(toSeconds: preferencesStore.resolveTimeout)
        resolveTimeoutPopUp.selectItem(withTitle: choice.title)
    }

    /// 값과 문구는 `ResolveTimeoutChoice`가 짝지어 소유하므로 인덱스가 아니라
    /// `representedObject`로 선택지를 실어 팝업 순서가 바뀌어도 어긋나지 않게 한다.
    private func makeResolveTimeoutPopUp() -> NSPopUpButton {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        for choice in ResolveTimeoutChoice.allCases {
            popUp.addItem(withTitle: choice.title)
            popUp.lastItem?.representedObject = choice.rawValue
        }
        popUp.target = self
        popUp.action = #selector(resolveTimeoutChanged(_:))
        return popUp
    }

    private func makeResolveTimeoutRow() -> NSStackView {
        let label = NSTextField(labelWithString: "Wait for unresponsive apps:")
        let row = NSStackView(views: [label, resolveTimeoutPopUp])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    /// 저장은 `PreferencesStore`가 클램프해서 하고, 실행 중인 앱에는 주입 클로저로 즉시 반영한다
    /// (재시작 없이 다음 명령부터 적용된다).
    @objc private func resolveTimeoutChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let choice = ResolveTimeoutChoice(rawValue: raw)
        else { return }
        preferencesStore.resolveTimeout = choice.seconds
        setResolveTimeout(preferencesStore.resolveTimeout)
        Log.app.info("Resolve timeout set to \(choice.rawValue, privacy: .public)")
    }
}
