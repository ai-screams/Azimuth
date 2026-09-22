<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# Hotkeys

## Purpose
Global hotkeys. Registers system-wide hotkeys through Carbon's `RegisterEventHotKey` and maps key combinations onto all 34 commands with presets (Standard/Vim). Supports custom shortcut overrides and disabling by group or by command.

## Key Files
| File | Description |
|------|-------------|
| `HotkeyService.swift` | `@MainActor` Carbon wrapper. `register` / `unregisterAll` / `reload(_:perform:)`. A single `InstallEventHandler` (`GetApplicationEventTarget`) plus the `nonisolated` C callback `hotkeyEventHandler`, which dispatches via `MainActor.assumeIsolated`. Signature `'AZMT'` |
| `HotkeyPreset.swift` | `nonisolated`. `HotkeyBinding` (command/keyCode/modifiers) + `HotkeyPreset` (`.standard` / `.vim`). A layered keymap: ⌃⌥ for halves, maximize, undo, center and the numeric splits (1/3, 2/3); ⌃⌥⌘ for moves; ⌃⌥⇧ for relative halves and two-thirds; ⌃⌥⌘⇧ for display moves. Vim replaces the arrow keys with H/J/K/L and undo with U |
| `BindingResolver.swift` | `nonisolated`. Merges user overrides (custom shortcuts) into the preset's default bindings, drops disabled commands and groups, and returns the final `[HotkeyBinding]`. Called by `AppDelegate.reloadHotkeys` |
| `HotkeyShortcut.swift` | The custom-shortcut value type. Stores, compares and serializes keyCode and modifiers. The value type behind `PreferencesStore.customShortcuts` |
| `CarbonModifier.swift` | Utility converting Carbon modifier constants to NSEvent modifier flags |

## For AI Agents

### Working In This Directory
- To expose a new command on a hotkey, add a `HotkeyBinding` to `HotkeyPreset.bindings`. `BindingResolver` only accepts overrides for commands present in `menuCommands`, so a command missing from the preset bindings cannot receive a custom shortcut either. Keep **key combinations unique** within both presets (a collision means one registration is rejected or skipped).
- Key codes are Carbon virtual key codes (`kVK_*`) and modifiers are Carbon constants (`controlKey|optionKey|cmdKey|shiftKey`). Do not confuse them with NSEvent modifiers.
- The Carbon callback arrives on the main run loop, so it enters through a `nonisolated` function plus `MainActor.assumeIsolated` (keep this pattern).
- Re-register after a preset change with `HotkeyService.reload`. `AppDelegate.reloadHotkeys` reads `PreferencesStore.activePreset` and calls it.

### Testing Requirements
- Registration is affected by permissions and by conflicts with other software, so verify it live with `make run`.
- **Binding uniqueness is checked by `make test`** (`Tests/CommandEngineTests+Hotkeys.swift`): that both presets cover all 34 `menuCommands` exactly once, and that no combination repeats within a preset. An older version of this document claimed the check happened "at build time" — no such check existed; in practice `RegisterEventHotKey` failed for individual bindings at runtime and only left a log line.
- `BindingResolver`, `HotkeyPreset`, `HotkeyShortcut` and `CarbonModifier` are in the harness (`scripts/harness-sources.sh`). Override merging, the disabled filter, conflict detection, display strings and Codable round-trips are all pinned by tests.

### Common Patterns
- A failed registration (`RegisterEventHotKey != noErr`) logs and skips — it never blocks the whole app. Combinations already taken by the system or another app are skipped naturally.

## Dependencies

### Internal
- `Commands/WindowCommand` (what bindings point at), `Preferences/PreferencesStore` (the active preset, via `AppDelegate`), `Shared/Log`.

### External
- Carbon.HIToolbox (hotkeys), Cocoa, os (Logger).

<!-- MANUAL: -->
