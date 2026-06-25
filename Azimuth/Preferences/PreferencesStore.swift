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
    private let customShortcutsKey = "customShortcuts"
    private let disabledCommandsKey = "disabledCommandIdentifiers"
    private let disabledGroupsKey = "disabledGroupTokens"
    private let menuBarIconHiddenKey = "menuBarIconHidden"
    private let migratedAbsoluteHalfRemovedKey = "migration.absoluteHalfRemoved.v1"

    /// feat/snap-throw-display: absolute half 명령 4개가 menuCommands에서 제거됨.
    /// 이전 버전에서 커스텀 단축키를 설정했다면 orphan 키가 남아 있으므로 한 번만 정리한다.
    private static let removedAbsoluteHalfIdentifiers: Set<String> = [
        "absolute.horizontal.half.first",
        "absolute.horizontal.half.last",
        "absolute.vertical.half.first",
        "absolute.vertical.half.last"
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateAbsoluteHalfRemoved()
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
            // UInt32 두 필드만 가진 Codable이라 인코딩은 사실상 실패하지 않는다(방어적 가드).
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: customShortcutsKey)
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
