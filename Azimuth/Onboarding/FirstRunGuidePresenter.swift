//
//  FirstRunGuidePresenter.swift
//  Azimuth
//
//  첫 실행 안내 팝오버 presenter — 상태바 버튼에 앵커해 1회 표시한다.
//  .accessory 앱에서 .transient 팝오버의 바깥 클릭 dismiss는 앱이 활성일 때만 동작하므로
//  표시 직전 activate하고, 명시적 기본 버튼(Got it / Open Settings…)을 항상 제공한다.
//

import Cocoa

@MainActor
final class FirstRunGuidePresenter: NSObject, NSPopoverDelegate {
    private var popover: NSPopover?

    func show(
        relativeTo button: NSStatusBarButton,
        launchService: LaunchAtLoginService,
        needsPermission: Bool,
        onOpenSettings: @escaping () -> Void
    ) {
        let pop = NSPopover()
        pop.behavior = .transient
        pop.delegate = self
        pop.contentViewController = FirstRunGuideViewController(
            launchService: launchService,
            needsPermission: needsPermission,
            onOpenSettings: onOpenSettings,
            onDone: { [weak self] in self?.dismiss() }
        )
        popover = pop
        NSApp.activate()
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func dismiss() {
        popover?.performClose(nil) // 해제는 popoverDidClose가 담당(바깥 클릭 닫힘과 경로 통일)
    }

    /// 닫힘 경로가 둘(기본 버튼 / transient 바깥 클릭)이라 delegate에서 한 번에 해제한다 —
    /// 닫힌 팝오버가 앱 수명 동안 리테인되는 것 방지.
    func popoverDidClose(_ notification: Notification) {
        popover = nil
    }
}
