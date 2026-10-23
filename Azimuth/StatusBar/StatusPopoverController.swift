//
//  StatusPopoverController.swift
//  Azimuth
//
//  메뉴바 팝오버(#178)를 띄우고 닫는다. 상태 버튼에 앵커하는 `NSPopover` + SwiftUI 내용.
//  .accessory 앱에서 transient 팝오버의 바깥 클릭 닫힘과 키보드 입력은 앱이 활성일 때만 동작하므로
//  열기 직전에 `NSApp.bringToFront()`로 활성화한다(`FirstRunGuidePresenter`와 같은 이유).
//  `NSMenu`는 앱을 활성화하지 않았으므로, 다른 창 없이 닫히면 활성화를 명령 대상 앱에 돌려준다.
//

import Cocoa
import SwiftUI

@MainActor
final class StatusPopoverController: NSObject, NSPopoverDelegate {
    let model: StatusPopoverModel
    private let popover = NSPopover()
    private let hosting: NSHostingController<StatusPopoverView>
    /// 닫힌 뒤 활성화를 돌려줄 앱(직전에 쓰던 앱).
    private let returnApplication: () -> NSRunningApplication?
    private weak var anchor: NSStatusBarButton?

    init(dependencies: StatusPopoverDependencies, returnApplication: @escaping () -> NSRunningApplication?) {
        model = StatusPopoverModel(dependencies: dependencies)
        hosting = NSHostingController(rootView: StatusPopoverView(model: model))
        self.returnApplication = returnApplication
        super.init()
        // 크기는 열기 전에 직접 잰다. 자동 크기(preferredContentSize)로 두면 팝오버가 처음 받은 크기가 틀려
        // 메뉴 막대 위로 밀려 올라갔다(실기). 내용이 바뀌면(실패 행) 모델이 알려 다시 잰다.
        hosting.sizingOptions = []
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = hosting
        model.onContentChange = { [weak self] in self?.fitContent() }
    }

    var isShown: Bool {
        popover.isShown
    }

    func show(relativeTo button: NSStatusBarButton) {
        model.refresh()
        fitContent()
        anchor = button
        NSApp.bringToFront()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        hosting.view.window?.makeKey()
    }

    private func fitContent() {
        // 너비는 뷰가 340으로 고정한다. 높이는 제한 없이 제안해 SwiftUI가 내용 전체 높이를 답하게 한다.
        // `view.fittingSize`는 창에 붙기 전이라 높이를 작게 답해 내용이 잘렸다(실기).
        let size = hosting.sizeThatFits(in: CGSize(width: 340, height: CGFloat.greatestFiniteMagnitude))
        guard size.width > 0, size.height > 0 else { return }
        popover.contentSize = size
    }

    func close() {
        popover.performClose(nil)
    }

    /// 상태 버튼을 다시 누른 것은 바깥 클릭으로 보지 않는다. 여기서 닫으면 버튼 동작이 닫힌 팝오버를 보고
    /// 다시 열어, 두 번째 클릭으로 닫히지 않는다. 그 클릭은 버튼 동작(`StatusClickPolicy`)이 닫는다.
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        guard let anchorWindow = anchor?.window, let event = NSApp.currentEvent else { return true }
        let isMouseDown = event.type == .leftMouseDown || event.type == .rightMouseDown
        return !(isMouseDown && event.window === anchorWindow)
    }

    /// Escape나 타일 뒤에 닫혀 Azimuth가 창 없이 활성으로 남으면 키 입력이 갈 곳이 없다. 직전 앱을 다시 활성화한다.
    /// 바깥 클릭으로 닫혔으면 이미 다른 앱이 활성이라 건너뛴다. 설정 창처럼 보이는 창이 있으면 그대로 둔다.
    func popoverDidClose(_ notification: Notification) {
        guard NSApp.isActive else { return }
        let hasWindow = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
        guard !hasWindow, let app = returnApplication(), !app.isTerminated else { return }
        _ = app.activate(from: .current)
    }
}
