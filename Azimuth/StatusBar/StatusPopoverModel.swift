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

    /// 동작을 먼저 하고 닫는다. 닫힐 때 다른 창이 없으면 활성화를 이전 앱에 돌려주므로(`StatusPopoverController`),
    /// 설정 창이 먼저 떠 있어야 Azimuth가 앞에 남는다.
    func openSettings() {
        dependencies.openSettings()
        dependencies.close()
    }

    func requestAccessibility() {
        dependencies.requestAccessibility()
        dependencies.close()
    }

    func checkForUpdates() {
        dependencies.checkForUpdates()
        dependencies.close()
    }

    func quit() {
        dependencies.quit()
    }

    func close() {
        dependencies.close()
    }
}
