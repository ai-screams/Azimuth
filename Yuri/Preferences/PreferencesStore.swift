//
//  PreferencesStore.swift
//  Yuri
//

import Foundation

@MainActor
final class PreferencesStore {
    private let defaults: UserDefaults
    private let activePresetKey = "activeHotkeyPreset"

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
}
