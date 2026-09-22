<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# Preferences

## Purpose
Persistence for user settings. A thin wrapper over UserDefaults.

## Key Files
| File | Description |
|------|-------------|
| `PreferencesStore.swift` | `@MainActor`. `activePreset: HotkeyPreset` (key `activeHotkeyPreset`, default `.standard`), `soundFeedbackEnabled: Bool` (key `soundFeedbackEnabled`, defaults to true when unset — an `object(forKey:)` nil check distinguishes "unset" from "false"), `notifyOnCommandFailure: Bool` (key `notifyOnCommandFailure`, default false — opt-in, and the notification authorization is requested only at the moment it is switched on) |

## For AI Agents

### Working In This Directory
- To add a setting: a private key constant plus a computed property (get/set). If a Bool needs to default to true, guard with `object(forKey:) != nil` to detect "unset" (plain `bool(forKey:)` returns false when unset).
- Everything is `@MainActor` (a single app-wide instance owned and injected by `AppDelegate`).

### Testing Requirements
- `make build` for compilation. Behavior is verified live (switching presets re-registers hotkeys; toggling feedback turns the beep on and off).

### Common Patterns
- Raw representations are stored as String (an enum rawValue) or Bool. A failed or unset read falls back to a safe default.

## Dependencies

### Internal
- `Hotkeys/HotkeyPreset` (the active preset type). Consumers: `AppDelegate` (hotkey reload, beep gating), `GeneralPaneViewController` and `Settings/ShortcutsSectionView` (UI).

### External
- Foundation (UserDefaults).

<!-- MANUAL: -->

<!-- MANUAL -->
- `resolveTimeout` (Float, Advanced settings): the AX resolution-stage messaging timeout in seconds. **Pass it through `AXMessagingTimeout.clampedResolve` on both read and write** — the stored value can be hand-edited, and AX reads 0 as "return to the global default (6s)", so leaving it alone would silently make the default behavior worse simply because a setting exists.
