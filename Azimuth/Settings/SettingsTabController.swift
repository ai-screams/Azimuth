//
//  SettingsTabController.swift
//  Azimuth
//
//  설정창 탭 컨테이너. 페인을 소유하고 탭 전환 시 창 높이를 그 페인에 맞춘다.
//
//  탭으로 나눈 이유: 카드를 한 세로 스크롤에 쌓으면 단축키 34개 때문에 창이 1,100pt를
//  넘겨 열린다. 단축키를 보러 온 게 아니어도 그 높이를 마주하게 된다.
//

import Cocoa

/// 페인이 창 높이 협상에 참여하기 위한 최소 규약. 각 페인은 자기 콘텐츠의 자연 높이를 안다.
@MainActor
protocol SettingsPane: NSViewController {
    /// 스크롤 없이 콘텐츠를 다 보여주는 데 필요한 높이.
    func naturalContentHeight() -> CGFloat
    /// 툴바 탭에 표시할 이름과 SF Symbol.
    var paneTitle: String { get }
    var paneSymbolName: String { get }
}

@MainActor
final class SettingsTabController: NSTabViewController {
    private let panes: [SettingsPane]
    /// 창 높이 하한. 이보다 낮아지면 페인 내부 스크롤뷰가 콘텐츠를 스크롤한다.
    static let minWindowHeight: CGFloat = 400

    init(panes: [SettingsPane]) {
        self.panes = panes
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        for pane in panes {
            let item = NSTabViewItem(viewController: pane)
            item.label = pane.paneTitle
            item.image = NSImage(systemSymbolName: pane.paneSymbolName, accessibilityDescription: pane.paneTitle)
            addTabViewItem(item)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 선택된 페인의 자연 높이(최소 높이 이상). 창 사이징에 쓴다.
    func preferredWindowHeight() -> CGFloat {
        guard selectedTabViewItemIndex >= 0, selectedTabViewItemIndex < panes.count else {
            // addTabViewItem이 뷰 로드 여부와 무관하게 첫 탭을 즉시 선택하므로(스탠드얼론 프로브로 확인)
            // 정상 경로에서는 이 분기에 닿지 않는다. 그런데도 닿으면 400pt 창이 "성공"처럼 보이므로
            // Debug 빌드에서만 알린다(Release에서는 assertionFailure가 no-op).
            assertionFailure("selectedTabViewItemIndex out of range — falling back to minWindowHeight")
            return Self.minWindowHeight
        }
        return max(panes[selectedTabViewItemIndex].naturalContentHeight(), Self.minWindowHeight)
    }

    /// 탭을 바꾸면 창 높이를 그 페인에 맞춘다. 폭은 고정이라 건드리지 않는다.
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        resizeWindowToSelectedPane()
    }

    func resizeWindowToSelectedPane() {
        guard let window = view.window else { return }
        let width = window.contentLayoutRect.width
        let height = preferredWindowHeight()
        window.contentMaxSize = NSSize(width: width, height: height)
        window.setContentSize(NSSize(width: width, height: height))
    }
}
