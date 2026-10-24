//
//  AppDelegate+Hotkeys.swift
//  Azimuth
//
//  전역 단축키 등록과 그 결과를 쓰는 곳(녹화 중 멈춤, 치트시트 켜기, 실제로 등록된 바인딩 조회). AppDelegate가 줄 수
//  상한을 넘어 파일을 나눴고, 그래서 여기서 쓰는 AppDelegate 속성은 `private`이 아니다.
//

import Foundation

extension AppDelegate {
    func reloadHotkeys() {
        let failed = hotkeyService.reload(enabledBindings()) { [weak self] command in
            self?.runCommand(command)
        }
        registrationFailureIdentifiers = Set(failed.map(\.command.identifier))
        // 팔레트 단축키는 명령이 아니어서 `reload`(먼저 전부 해제한다) 뒤에 따로 건다. 실패는 설정의 팔레트 줄이 보인다.
        let opensPalette = commandPaletteController.registerHotkey(on: hotkeyService) { [weak self] in
            self?.cheatSheetController.commandRan()
        }
        if !opensPalette { registrationFailureIdentifiers.insert(CommandPaletteShortcut.identifier) }
    }

    /// 단축키 녹화 중에는 전역 핫키를 모두 해제하고, 끝나면 다시 등록한다(녹화 조합의 오발화 방지).
    func setHotkeysSuspended(_ suspended: Bool) {
        hotkeysSuspended = suspended
        updateCheatSheet()
        if suspended {
            hotkeyService.unregisterAll()
        } else {
            reloadHotkeys()
        }
    }

    /// 치트시트 감시를 켤지: 설정이 켜져 있고, 권한이 있고(없으면 전역 키 이벤트가 오지 않는다), 녹화 중이 아닐 때.
    /// 권한이 생기면 이 함수로 감시를 새로 건다.
    func updateCheatSheet() {
        let active = preferencesStore.cheatSheetEnabled
            && AccessibilityPermissionService.currentStatus().isTrusted
            && !hotkeysSuspended
        cheatSheetController.setActive(active, delay: preferencesStore.cheatSheetDelay)
    }

    /// 등록할 바인딩: 프리셋 + 사용자 지정에서 꺼진 명령과 그룹을 뺀 것. 등록(`reloadHotkeys`)과 연습 창이 같이 쓴다.
    func enabledBindings() -> [HotkeyBinding] {
        let resolved = BindingResolver.resolve(
            preset: preferencesStore.activePreset,
            overrides: preferencesStore.customShortcuts
        )
        return BindingResolver.enabled(
            resolved,
            disabledCommands: preferencesStore.disabledCommandIdentifiers,
            disabledGroups: preferencesStore.disabledGroupTokens
        )
    }

    /// 실제로 눌러서 오는 바인딩: 켜진 것 중 등록에 실패하지 않은 것(다른 앱이 쓰는 조합은 눌러도 오지 않는다).
    /// 연습 창·팝오버 키캡과 치트시트가 같이 쓴다.
    func registeredBindings() -> [HotkeyBinding] {
        enabledBindings().filter { !registrationFailureIdentifiers.contains($0.command.identifier) }
    }

    func boundShortcut(for command: WindowCommand) -> HotkeyShortcut? {
        registeredBindings().first { $0.command == command }?.shortcut
    }
}
