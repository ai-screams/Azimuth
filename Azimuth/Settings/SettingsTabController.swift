//
//  SettingsTabController.swift
//  Azimuth
//
//  설정창 탭 컨테이너. 페인을 소유하고, 창 크기는 General 높이로 고정한다(레거시판).
//
//  탭으로 나눈 이유: 카드를 한 세로 스크롤에 쌓으면 단축키 34개 때문에 창이 1,100pt를
//  넘겨 열린다. 단축키를 보러 온 게 아니어도 그 높이를 마주하게 된다.
//

import Cocoa

/// 페인이 설정창에 참여하기 위한 최소 규약. 고정 창 높이는 첫 페인(General)의 자연 높이로 정한다.
@MainActor
protocol SettingsPane: NSViewController {
    /// 스크롤 없이 콘텐츠를 다 보여주는 데 필요한 높이.
    func naturalContentHeight() -> CGFloat
    /// 툴바 탭에 표시할 이름과 SF Symbol.
    var paneTitle: String { get }
    var paneSymbolName: String { get }
    /// 이 탭을 고를 때 처음 포커스를 받을 뷰. nil이면 AppKit 기본값.
    var initialFocusView: NSView? { get }
}

extension SettingsPane {
    var initialFocusView: NSView? {
        nil
    }
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
        // 툴바 탭은 아이콘 자리를 비워 두므로, SF Symbol이 없는 11 미만은 세그먼트 탭으로 그린다.
        if #available(macOS 11.0, *) { tabStyle = .toolbar } else { tabStyle = .segmentedControlOnTop }
        for pane in panes {
            let item = NSTabViewItem(viewController: pane)
            item.label = pane.paneTitle
            item.image = NSImage.symbol(pane.paneSymbolName, accessibilityDescription: pane.paneTitle)
            // 탭을 고를 때 AppKit이 기본 키 뷰 루프를 처음부터 계산하지 않게 첫 포커스를 정해 둔다(뷰가 많은
            // Shortcuts에서 전환 비용의 약 20%). 나머지 순서는 창의 자동 재계산(`autorecalculatesKeyViewLoop`)에 맡긴다.
            item.initialFirstResponder = pane.initialFocusView
            addTabViewItem(item)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 레거시판: 창 크기를 General(첫 탭)의 자연 높이로 고정한다. 탭을 바꾸거나 그룹을 펼쳐도 창은
    /// 그대로이고, 더 긴 페인(Shortcuts)은 페인 스크롤뷰 안에서 스크롤한다. General의 내용(권한 상태 문구,
    /// 승인 안내 등)은 바뀔 수 있으므로 저장해 두지 않고 부를 때마다 잰다 — General은 작아 비용이 작다.
    private func measuredFixedHeight() -> CGFloat {
        guard let first = tabViewItems.first?.viewController as? SettingsPane else {
            // 정상 경로에서는 닿지 않는다(패널 목록이 비지 않는다). 닿으면 400pt 창이 "성공"처럼 보이므로
            // Debug 빌드에서만 알린다(Release는 no-op).
            assertionFailure("no SettingsPane for the first tab — falling back to minWindowHeight")
            return Self.minWindowHeight
        }
        // 페인 콘텐츠 높이에 탭 컨트롤러가 차지하는 높이를 더한다. 11 미만의 세그먼트 탭은 창 콘텐츠 안에
        // 자리를 잡으므로(툴바 탭은 창 툴바에 있어 0) 빼먹으면 General이 제 높이에서도 스크롤된다.
        // General이 선택되지 않았을 땐 그 뷰가 계층에서 떨어져 옛 크기를 들고 있으므로, 탭 컨테이너(`tabView`)
        // 기준으로 잰다.
        view.layoutSubtreeIfNeeded()
        let chromeHeight = max(0, view.bounds.height - tabView.contentRect.height)
        return max(first.naturalContentHeight() + chromeHeight, Self.minWindowHeight)
    }

    /// 창의 최소·최대 크기를 같은 값으로 묶어 고정한다. 창을 만들 때, 보여 줄 때(짧은 화면에서 AppKit이
    /// 줄여 놓은 창을 되돌림), General의 내용이 바뀔 때 부른다.
    func applyFixedWindowSize() {
        guard let window = view.window else { return }
        let size = NSSize(width: Self.windowWidth, height: measuredFixedHeight())
        window.contentMinSize = size
        window.contentMaxSize = size
        if window.contentLayoutRect.size != size { window.setContentSize(size) }
    }
}
