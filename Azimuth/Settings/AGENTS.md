<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-10-22 -->

# Settings

## Purpose
The settings window. Since #175 it is a SwiftUI `NavigationSplitView` with a sidebar (**General / Shortcuts / Advanced / About**) and a grouped `Form` per pane, laid out like System Settings. The window itself is still created, placed and shown by `SettingsWindowController` (AppKit).

## Key Files
| File | Description |
|------|-------------|
| `SettingsWindowController.swift` | `@MainActor`. Takes a `SettingsDependencies` bundle, owns the `SettingsModel`, and hosts `SettingsRootView` in an `NSHostingController` (`sizingOptions = []`, so the window does not jump to the content's preferred size; initial 760×600, tall enough for About without scrolling, minimum 640×420). `show(pane:)` refreshes the model, centers the window on the screen holding the mouse and brings the app forward. Observes `didBecomeActive` to refresh after the user changes things in System Settings. `setCanCheckForUpdates` is how `AppDelegate` passes Sparkle's state |
| `SettingsModel.swift` | `@Observable`. `SettingsDependencies` (store, login-item service, and closures for hotkeys, menu-bar icon, resolve timeout, Sparkle and notification authorization) plus the values the panes show. `refresh()` re-reads everything (permission, login item — `SMAppService` has no change notification — store values) and clears the notify hint. Actions keep the old behavior: notify-on-failure goes through `Notifications/NotifyToggleDecision`; launch-at-login beeps on failure only when sound feedback is on and refreshes after `disable` completes; undo text goes through `BoundedIntSetting.parse` (non-numbers revert), the store clamps |
| `SettingsRootView.swift` | Sidebar + detail. An orange dot next to General when Accessibility is not granted. The sidebar toggle is removed |
| `GeneralSettingsView.swift` | Permissions, Startup (launch at login + approval row, hide menu bar icon + reopen hint), Feedback (sound, notify + System Settings hint). Toggles are switches |
| `AdvancedSettingsView.swift` | Undo (steps per window, windows to remember: a text field committed on Return or focus loss, plus a stepper) and "Wait for unresponsive apps" (`ResolveTimeoutChoice`) |
| `AboutSettingsView.swift` | Icon, name, version, tagline, Updates ("Check for Updates…" disabled while Sparkle cannot check), links and copyright from `Shared/AboutContent`. The app menu's "About Azimuth" opens this pane (`show(pane: .about)`); there is no separate About window |
| `ShortcutsSettingsModel.swift` | `@Observable`. Preset, search text, expanded groups (not saved: every group starts collapsed), the command being recorded, and each command's row display from `Commands/ShortcutListPolicy` (groups) and `Commands/ShortcutRowPolicy` (rows). Every change re-registers hotkeys (`onHotkeysChanged`) and re-reads registration failures. Global hotkeys are suspended while recording; transitions come from `Commands/ShortcutRecordingPolicy` and the only `setHotkeysSuspended` call is `apply(_:)`, and recording is cancelled when its row leaves the screen (collapse, search, pane switch, window close) |
| `ShortcutsSettingsView.swift` | The Shortcuts pane: preset, Reset All, search in the window toolbar, one section per group (disclosure + enable checkbox), rows of checkbox · command glyph · name with Duplicate / In use by system · customized dot · keycaps · ↺ (only when customized, keeps its space). Clicking the keycaps records in place |
| `ShortcutKeyCatcher.swift` | Invisible AppKit view put behind the keycaps while recording. Becomes first responder and passes the next key to `Commands/ShortcutCapturePolicy`; also takes ⌘ combos before the main menu. Reports the end once, on capture, Esc, Tab, losing focus or leaving the window. SwiftUI `onKeyPress` is not used: it does not give the key code Carbon needs |

## For AI Agents

### Working In This Directory
- A new setting goes into `SettingsModel` (value + action) and one pane view. Pick the pane by audience: General for everyday users, Shortcuts for key bindings, Advanced for things nobody should need to change.
- Keep decisions out of the views. A decision with branches (like the notify toggle) becomes a pure type in the harness.
- UI files never import Sparkle or UserNotifications; they get closures through `SettingsDependencies`.
- Window placement follows the screen containing `NSEvent.mouseLocation`. Keep it (multi-monitor regression).
- A new way for recording to end must still reach `ShortcutsSettingsModel.finishRecording`, or global hotkeys stay suspended. Verify recording with a real hotkey afterwards (`HotkeyService` is not reached from the menu).

### Testing Requirements
- `make lint` + `make test` (`NotifyToggleDecision`, `ShortcutListPolicy`, `ShortcutRowPolicy`, `ShortcutCapturePolicy`, `ShortcutRecordingPolicy`) + Debug and Release compile. Human check with `make run`: every control saves, reads back after reopening and takes effect; notify denied shows the hint; login item needing approval shows its row; undo fields reject `abc` and clamp `0` / `999`; hide the icon and reopen from Finder; the General dot when permission is missing; Shortcuts records (Esc, Tab, a key without modifiers, ⌘ combos, clicking elsewhere, collapsing or searching mid-recording), shows Duplicate, resets, and the new combo works as a real hotkey; the window opens on the screen with the mouse.

## Dependencies

### Internal
- `Preferences/PreferencesStore`, `Launch/LaunchAtLoginService`, `Permissions/AccessibilityPermissionService`, `Notifications/NotifyToggleDecision`, `Commands/ShortcutListPolicy` · `ShortcutRowPolicy` · `ShortcutCapturePolicy`, `Hotkeys/*`, `Shared/AXMessagingTimeout` (`ResolveTimeoutChoice`), `Shared/AboutContent`, `Shared/BundleVersion`, `UI/CommandGlyphView` · `KeycapsView`.

### External
- SwiftUI, Observation, Cocoa.

<!-- MANUAL: -->
