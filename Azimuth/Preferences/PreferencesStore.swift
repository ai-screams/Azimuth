//
//  PreferencesStore.swift
//  Azimuth
//

import Foundation
import os

@MainActor
final class PreferencesStore {
    private let defaults: UserDefaults
    private let activePresetKey = "activeHotkeyPreset"
    private let soundFeedbackKey = "soundFeedbackEnabled"
    private let notifyOnCommandFailureKey = "notifyOnCommandFailure"
    private let customShortcutsKey = "customShortcuts"
    private let disabledCommandsKey = "disabledCommandIdentifiers"
    private let disabledGroupsKey = "disabledGroupTokens"
    private let menuBarIconHiddenKey = "menuBarIconHidden"
    private let didCompleteFirstRunKey = "didCompleteFirstRun"
    private let didAttemptAccessibilityPromptKey = "didAttemptAccessibilityPrompt"
    private let resolveTimeoutKey = "resolveTimeout"
    private let undoDepthKey = "undoDepth"
    private let undoWindowCapacityKey = "undoWindowCapacity"
    private let cheatSheetEnabledKey = "cheatSheetEnabled"
    private let cheatSheetDelayKey = "cheatSheetDelayMilliseconds"
    private let commandPaletteEnabledKey = "commandPaletteEnabled"
    private let commandPaletteShortcutKey = "commandPaletteShortcut"
    private let commandPaletteRecentKey = "commandPaletteRecent"
    private let migratedAbsoluteHalfRemovedKey = "migration.absoluteHalfRemoved.v1"

    /// feat/snap-throw-display: absolute half 명령 4개가 menuCommands에서 제거됨.
    /// 이전 버전에서 커스텀 단축키를 설정했다면 orphan 키가 남아 있으므로 한 번만 정리한다.
    private static let removedAbsoluteHalfIdentifiers: Set<String> = [
        "absolute.horizontal.half.first",
        "absolute.horizontal.half.last",
        "absolute.vertical.half.first",
        "absolute.vertical.half.last"
    ]

    /// 고급 설정: AX 해석 단계 messaging timeout(초). 저장 값은 손으로 편집될 수 있으므로
    /// 읽을 때도 쓸 때도 클램프한다 — 0은 AX가 "전역 기본값(6초) 복귀"로 해석해서, 그대로 두면
    /// 이 설정이 있다는 이유로 기본 동작이 조용히 나빠진다.
    var resolveTimeout: Float {
        get {
            guard defaults.object(forKey: resolveTimeoutKey) != nil else { return AXMessagingTimeout.resolve }
            return AXMessagingTimeout.clampedResolve(defaults.float(forKey: resolveTimeoutKey))
        }
        set { defaults.set(AXMessagingTimeout.clampedResolve(newValue), forKey: resolveTimeoutKey) }
    }

    /// 창마다 기억할 Undo 단계 수(#170).
    var undoDepth: Int {
        get { boundedInt(forKey: undoDepthKey, UndoHistory.depth) }
        set { defaults.set(UndoHistory.depth.clamped(newValue), forKey: undoDepthKey) }
    }

    /// Undo 기록을 들고 있을 창 수(#170).
    var undoWindowCapacity: Int {
        get { boundedInt(forKey: undoWindowCapacityKey, UndoHistory.windowCapacity) }
        set { defaults.set(UndoHistory.windowCapacity.clamped(newValue), forKey: undoWindowCapacityKey) }
    }

    /// 저장 값은 손으로 편집될 수 있으므로 읽을 때도 쓸 때도 클램프한다. 없으면 기본값.
    private func boundedInt(forKey key: String, _ setting: BoundedIntSetting) -> Int {
        guard defaults.object(forKey: key) != nil else { return setting.defaultValue }
        return setting.clamped(defaults.integer(forKey: key))
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateAccessibilityPromptHistory()
        migrateAbsoluteHalfRemoved()
    }

    /// 권한 알림 시도 기록이 없으면 한 번만 정해 저장한다. 첫 실행 안내가 `didCompleteFirstRun`을 켜기 전인
    /// 여기서 해야 새 설치본이 "이미 시도함"으로 잘못 정해지지 않는다(`AccessibilityRequestPolicy`).
    private func migrateAccessibilityPromptHistory() {
        let recorded = defaults.object(forKey: didAttemptAccessibilityPromptKey) as? Bool
        guard recorded == nil else { return }
        let initial = AccessibilityRequestPolicy.initialAttemptFlag(
            recorded: recorded, didCompleteFirstRun: defaults.bool(forKey: didCompleteFirstRunKey)
        )
        defaults.set(initial, forKey: didAttemptAccessibilityPromptKey)
    }

    private func migrateAbsoluteHalfRemoved() {
        guard !defaults.bool(forKey: migratedAbsoluteHalfRemovedKey) else { return }
        var shortcuts = customShortcuts
        let before = shortcuts.count
        shortcuts = shortcuts.filter { !Self.removedAbsoluteHalfIdentifiers.contains($0.key) }
        if shortcuts.count != before {
            customShortcuts = shortcuts
            Log.app.info("Pruned \(before - shortcuts.count) orphaned absolute-half customShortcuts entries.")
        }
        defaults.set(true, forKey: migratedAbsoluteHalfRemovedKey)
    }

    var activePreset: HotkeyPreset {
        get {
            guard let raw = defaults.string(forKey: activePresetKey),
                  let preset = HotkeyPreset(rawValue: raw)
            else {
                return .standard
            }
            return preset
        }
        set {
            defaults.set(newValue.rawValue, forKey: activePresetKey)
        }
    }

    /// 수정키를 누르고 있으면 단축키 치트시트를 띄울지(#182). 미설정 시 켜짐.
    var cheatSheetEnabled: Bool {
        get {
            guard defaults.object(forKey: cheatSheetEnabledKey) != nil else { return true }
            return defaults.bool(forKey: cheatSheetEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: cheatSheetEnabledKey)
        }
    }

    /// 치트시트를 띄우기 전 기다리는 시간. 손으로 편집된 값은 읽을 때 선택지로 되돌린다(`CheatSheetDelay.stored`).
    var cheatSheetDelay: CheatSheetDelay {
        get {
            let stored = defaults.object(forKey: cheatSheetDelayKey) as? Int
            return CheatSheetDelay.stored(stored)
        }
        set {
            defaults.set(newValue.rawValue, forKey: cheatSheetDelayKey)
        }
    }

    /// 명령 팔레트 단축키를 등록할지(#183). 미설정 시 켜짐.
    var commandPaletteEnabled: Bool {
        get {
            guard defaults.object(forKey: commandPaletteEnabledKey) != nil else { return true }
            return defaults.bool(forKey: commandPaletteEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: commandPaletteEnabledKey)
        }
    }

    /// 팔레트를 여는 조합. 저장 값이 없거나 읽지 못하면 기본(⌃⌥P). nil을 대입하면 기본으로 되돌린다.
    var commandPaletteShortcut: HotkeyShortcut {
        get {
            guard let data = defaults.data(forKey: commandPaletteShortcutKey),
                  let shortcut = try? JSONDecoder().decode(HotkeyShortcut.self, from: data)
            else { return CommandPaletteShortcut.standard }
            return shortcut
        }
        set {
            if newValue == CommandPaletteShortcut.standard {
                defaults.removeObject(forKey: commandPaletteShortcutKey)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: commandPaletteShortcutKey)
            }
        }
    }

    /// 기본값과 다른 조합을 저장했는지(설정의 사용자 지정 점·되돌리기).
    var hasCustomCommandPaletteShortcut: Bool {
        defaults.data(forKey: commandPaletteShortcutKey) != nil
    }

    /// 팔레트로 실행한 명령 식별자, 최근이 앞. 상한은 `CommandPaletteRecents`가 지킨다.
    var commandPaletteRecent: [String] {
        get { defaults.stringArray(forKey: commandPaletteRecentKey) ?? [] }
        set { defaults.set(Array(newValue.prefix(CommandPaletteRecents.capacity)), forKey: commandPaletteRecentKey) }
    }

    /// 명령 실패 시 비프음 재생 여부. 미설정 시 기본 활성화.
    var soundFeedbackEnabled: Bool {
        get {
            guard defaults.object(forKey: soundFeedbackKey) != nil else { return true }
            return defaults.bool(forKey: soundFeedbackKey)
        }
        set {
            defaults.set(newValue, forKey: soundFeedbackKey)
        }
    }

    /// 명령 실패 시 사유를 담은 사용자 알림 표시 여부. 기본 비활성(opt-in) —
    /// 켜는 순간에만 알림 권한을 요청하고, 거부되면 UI가 다시 끈다.
    var notifyOnCommandFailure: Bool {
        get {
            defaults.bool(forKey: notifyOnCommandFailureKey)
        }
        set {
            defaults.set(newValue, forKey: notifyOnCommandFailureKey)
        }
    }

    /// 명령 identifier → 사용자 커스텀 단축키. 프리셋 기본값을 덮어쓴다(BindingResolver).
    /// JSON으로 UserDefaults에 저장. 디코딩 실패 시 빈 맵으로 폴백(설정 손상이 앱을 막지 않게).
    var customShortcuts: [String: HotkeyShortcut] {
        get {
            guard let data = defaults.data(forKey: customShortcutsKey) else { return [:] }
            do {
                return try JSONDecoder().decode([String: HotkeyShortcut].self, from: data)
            } catch {
                // 손상된 설정이 앱을 막지 않게 빈 맵으로 폴백하되, 원인은 남긴다.
                Log.app.error("Failed to decode customShortcuts: \(error.localizedDescription, privacy: .public)")
                return [:]
            }
        }
        set {
            // UInt32 두 필드만 가진 Codable이라 인코딩은 사실상 실패하지 않지만, 실패 시 조용히
            // 삼키면 단축키 변경이 저장 안 된 이유를 진단할 수 없다 → 로그를 남긴다(방어적 가드).
            do {
                try defaults.set(JSONEncoder().encode(newValue), forKey: customShortcutsKey)
            } catch {
                Log.app.error("Failed to encode customShortcuts: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func setShortcut(_ shortcut: HotkeyShortcut, forCommand identifier: String) {
        var shortcuts = customShortcuts
        shortcuts[identifier] = shortcut
        customShortcuts = shortcuts
    }

    func clearShortcut(forCommand identifier: String) {
        var shortcuts = customShortcuts
        shortcuts.removeValue(forKey: identifier)
        customShortcuts = shortcuts
    }

    func clearAllShortcuts() {
        customShortcuts = [:]
    }

    // MARK: - 명령/그룹 활성화 (Phase 7d)

    /// 개별 비활성(unbind)된 명령 식별자.
    var disabledCommandIdentifiers: Set<String> {
        get { Set(defaults.stringArray(forKey: disabledCommandsKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: disabledCommandsKey) }
    }

    /// 그룹째 비활성된 그룹 토큰.
    var disabledGroupTokens: Set<String> {
        get { Set(defaults.stringArray(forKey: disabledGroupsKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: disabledGroupsKey) }
    }

    /// 메뉴바 상태 아이콘 숨김 여부. defaults.bool은 미설정 키에 false를 주는데,
    /// 그게 곧 올바른 기본값(아이콘 표시)이라 별도 처리 불필요.
    var menuBarIconHidden: Bool {
        get { defaults.bool(forKey: menuBarIconHiddenKey) }
        set { defaults.set(newValue, forKey: menuBarIconHiddenKey) }
    }

    /// 손쉬운 사용 권한 알림을 시도했는가(실제로 떴는지·허용했는지가 아니라 **요청을 보냈는지**).
    var didAttemptAccessibilityPrompt: Bool {
        get { defaults.bool(forKey: didAttemptAccessibilityPromptKey) }
        set { defaults.set(newValue, forKey: didAttemptAccessibilityPromptKey) }
    }

    /// 첫 실행 온보딩(권한 안내 창)을 이미 띄웠는지. 미설정(false)=아직 안 띄움 → 첫 실행에서만 1회 노출.
    var didCompleteFirstRun: Bool {
        get { defaults.bool(forKey: didCompleteFirstRunKey) }
        set { defaults.set(newValue, forKey: didCompleteFirstRunKey) }
    }

    /// 그룹이 켜져 있고 개별 비활성도 아니어야 명령이 활성이다.
    func isCommandEnabled(_ identifier: String, groupToken: String) -> Bool {
        !disabledGroupTokens.contains(groupToken) && !disabledCommandIdentifiers.contains(identifier)
    }

    func setCommandDisabled(_ identifier: String, disabled: Bool) {
        var set = disabledCommandIdentifiers
        if disabled { set.insert(identifier) } else { set.remove(identifier) }
        disabledCommandIdentifiers = set
    }

    func isGroupEnabled(_ token: String) -> Bool {
        !disabledGroupTokens.contains(token)
    }

    func setGroupDisabled(_ token: String, disabled: Bool) {
        var set = disabledGroupTokens
        if disabled { set.insert(token) } else { set.remove(token) }
        disabledGroupTokens = set
    }
}
