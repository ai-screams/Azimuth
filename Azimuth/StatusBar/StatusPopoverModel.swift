//
//  StatusPopoverModel.swift
//  Azimuth
//
//  메뉴바 팝오버(#178)의 상태와 동작. 앱 상태(권한, 마지막 실패, 단축키)는 주입한 클로저로 묻고,
//  팝오버가 열릴 때마다 `refresh()`로 다시 읽는다.
//

import Observation

/// 팝오버가 앱에 되묻는 경로. `StatusBarController`가 AppDelegate에서 받은 클로저로 채운다.
struct StatusPopoverDependencies {
    /// 단축키와 같은 실행 경로(실패 비프, 마지막 실패 사유, 알림).
    let run: (WindowCommand) -> Void
    /// 지금 실제로 등록된 단축키. 꺼졌거나 등록에 실패했으면 nil.
    let shortcut: (WindowCommand) -> HotkeyShortcut?
    let isTrusted: () -> Bool
    let lastFailure: () -> String?
    let openSettings: () -> Void
    let requestAccessibility: () -> Void
    let checkForUpdates: () -> Void
    let quit: () -> Void
    let close: () -> Void
    /// 창을 띄운 단추 뒤에 닫는다. 그 창이 앞에 남도록 활성화를 돌려주지 않는다.
    let closeForWindow: () -> Void
}

@Observable
final class StatusPopoverModel {
    private(set) var isTrusted = false
    private(set) var lastFailure: String?
    /// 마지막으로 누른 명령. 아래 줄에 이름과 키캡을 보이고 그 타일만 강조색으로 그린다.
    private(set) var applied: WindowCommand?
    /// 키보드 커서(`PopoverGridLayout.commands` 인덱스). 마우스만 쓰면 nil.
    var cursor: Int?
    var canCheckForUpdates = true

    @ObservationIgnored private let dependencies: StatusPopoverDependencies
    /// 높이가 바뀔 수 있는 변화(실패 행이 생기거나 사라짐) 뒤에 부른다. 컨트롤러가 팝오버 크기를 다시 잰다.
    @ObservationIgnored var onContentChange: (() -> Void)?

    init(dependencies: StatusPopoverDependencies) {
        self.dependencies = dependencies
    }

    /// 팝오버를 열 때마다 부른다. 지난번 선택과 커서는 지운다.
    func refresh() {
        isTrusted = dependencies.isTrusted()
        lastFailure = dependencies.lastFailure()
        applied = nil
        cursor = nil
    }

    func apply(_ command: WindowCommand) {
        guard isTrusted else { return }
        dependencies.run(command)
        applied = command
        lastFailure = dependencies.lastFailure()
        onContentChange?()
    }

    func applyCursor() {
        guard let cursor, PopoverGridLayout.commands.indices.contains(cursor) else { return }
        apply(PopoverGridLayout.commands[cursor])
    }

    func moveCursor(_ move: PopoverGridLayout.Move) {
        cursor = PopoverGridLayout.standard.moved(from: cursor, move)
    }

    func shortcut(for command: WindowCommand) -> HotkeyShortcut? {
        dependencies.shortcut(command)
    }

    /// 창을 띄우는 단추. 닫으면서 활성화를 직전 앱에 돌려주지 않는다(`PopoverActivationPolicy`).
    func openSettings() {
        dependencies.openSettings()
        dependencies.closeForWindow()
    }

    func requestAccessibility() {
        dependencies.requestAccessibility()
        dependencies.closeForWindow()
    }

    func checkForUpdates() {
        dependencies.checkForUpdates()
        dependencies.closeForWindow()
    }

    func quit() {
        dependencies.quit()
    }

    func close() {
        dependencies.close()
    }
}
