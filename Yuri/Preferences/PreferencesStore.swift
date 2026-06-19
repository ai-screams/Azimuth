//
//  PreferencesStore.swift
//  Yuri
//

import Foundation

@MainActor
final class PreferencesStore {
    private let defaults: UserDefaults
    private let activePresetKey = "activeHotkeyPreset"
    private let soundFeedbackKey = "soundFeedbackEnabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
}
