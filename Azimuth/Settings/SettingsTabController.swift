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
    /// 창 폭(고정, 가로 리사이즈 없음). 페인 콘텐츠 폭(480/512)에 맞춰 튜닝된 값이라 창과 페인이
    /// 같은 수를 봐야 한다 — 어긋나면 자연 높이가 틀린 폭 기준으로 계산되는데 하네스가 잡지 못한다.
    static let windowWidth: CGFloat = 560
    /// 창 높이 하한. 이보다 낮아지면 페인 내부 스크롤뷰가 콘텐츠를 스크롤한다.
    static let minWindowHeight: CGFloat = 400

    init(panes: [SettingsPane]) {
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
    ///
    /// `tabViewItems`(프레임워크가 소유)에서 직접 꺼낸다 — 별도 배열을 들고 인덱스로 맞추면
    /// 범위는 맞는데 페인이 어긋나는 상태가 조용히 생길 수 있다(상속받은 addTabViewItem 등은
    /// final 클래스에서도 외부 호출이 열려 있다).
    func preferredWindowHeight() -> CGFloat {
        let items = tabViewItems
        guard selectedTabViewItemIndex >= 0, selectedTabViewItemIndex < items.count,
              let pane = items[selectedTabViewItemIndex].viewController as? SettingsPane
        else {
            // 정상 경로에서는 닿지 않는다(addTabViewItem이 첫 탭을 즉시 선택한다). 그런데도 닿으면
            // 400pt 창이 "성공"처럼 보이므로 Debug 빌드에서만 알린다(Release는 no-op).
            assertionFailure("no SettingsPane for selected tab — falling back to minWindowHeight")
            return Self.minWindowHeight
        }
        return max(pane.naturalContentHeight(), Self.minWindowHeight)
    }

    /// 탭을 바꾸면 창 높이를 그 페인에 맞춘다. 폭은 고정이라 건드리지 않는다.
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        resizeWindowToSelectedPane()
    }

    func resizeWindowToSelectedPane() {
        guard let window = view.window else { return }
        let width = Self.windowWidth // contentMinSize 와 같은 출처 — 어긋나면 min/max 폭이 갈린다
        let height = preferredWindowHeight()
        window.contentMaxSize = NSSize(width: width, height: height)
        window.setContentSize(NSSize(width: width, height: height))
    }
}
