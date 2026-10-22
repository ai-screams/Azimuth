<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-10-22 -->

# Settings

## Purpose
The settings window. Since #175 it is a SwiftUI `NavigationSplitView` with a sidebar (**General / Shortcuts / Advanced / About**) and a grouped `Form` per pane, laid out like System Settings. The window itself is still created, placed and shown by `SettingsWindowController` (AppKit). The Shortcuts pane is still the AppKit `ShortcutsPaneViewController`, hosted through `NSViewControllerRepresentable`; moving it to SwiftUI is the second step of #175.

## Key Files
| File | Description |
|------|-------------|
| `SettingsWindowController.swift` | `@MainActor`. Takes a `SettingsDependencies` bundle, owns the `SettingsModel`, and hosts `SettingsRootView` in an `NSHostingController` (`sizingOptions = []`, so the window does not jump to the content's preferred size; initial 760×600, tall enough for About without scrolling, minimum 640×420). `show(pane:)` refreshes the model, centers the window on the screen holding the mouse and brings the app forward. Observes `didBecomeActive` to refresh after the user changes things in System Settings. `setCanCheckForUpdates` is how `AppDelegate` passes Sparkle's state |
| `SettingsModel.swift` | `@Observable`. `SettingsDependencies` (store, login-item service, and closures for hotkeys, menu-bar icon, resolve timeout, Sparkle and notification authorization) plus the values the panes show. `refresh()` re-reads everything (permission, login item — `SMAppService` has no change notification — store values) and clears the notify hint. Actions keep the old behavior: notify-on-failure goes through `Notifications/NotifyToggleDecision`; launch-at-login beeps on failure only when sound feedback is on and refreshes after `disable` completes; undo text goes through `BoundedIntSetting.parse` (non-numbers revert), the store clamps |
| `SettingsRootView.swift` | Sidebar + detail. An orange dot next to General when Accessibility is not granted. The sidebar toggle is removed |
| `GeneralSettingsView.swift` | Permissions, Startup (launch at login + approval row, hide menu bar icon + reopen hint), Feedback (sound, notify + System Settings hint). Toggles are switches |
| `AdvancedSettingsView.swift` | Undo (steps per window, windows to remember: a text field committed on Return or focus loss, plus a stepper) and "Wait for unresponsive apps" (`ResolveTimeoutChoice`) |
| `AboutSettingsView.swift` | Icon, name, version, tagline, Updates ("Check for Updates…" disabled while Sparkle cannot check), links and copyright from `Shared/AboutContent` |
| `ShortcutsSettingsHost.swift` | Hosts `ShortcutsPaneViewController` until the Shortcuts pane moves to SwiftUI |
| `ShortcutsPaneViewController.swift` | The AppKit Shortcuts pane: a card holding `ShortcutsSectionView` in a scroll view. Collapses every group each time it appears |
| `ShortcutsSectionView.swift` / `+Layout.swift` / `+Pruning.swift` | Preset control, search and 34 command rows (recorder, Reset, modified dot, conflict/occupied badges). Visibility comes from `Commands/ShortcutListPolicy`, row appearance from `Commands/ShortcutRowPolicy`. Pruning keeps hidden slots out of the view hierarchy (#137) and cancels a recording before its row leaves, so global hotkeys never stay suspended |
| `SettingsCard.swift` / `SettingsPaneScaffold.swift` / `BadgeLabel.swift` / `ShortcutRecorderButton.swift` | AppKit parts used only by the Shortcuts pane now. Removed when that pane moves to SwiftUI |

## For AI Agents

### Working In This Directory
- A new setting goes into `SettingsModel` (value + action) and one pane view. Pick the pane by audience: General for everyday users, Shortcuts for key bindings, Advanced for things nobody should need to change.
- Keep decisions out of the views. A decision with branches (like the notify toggle) becomes a pure type in the harness.
- UI files never import Sparkle or UserNotifications; they get closures through `SettingsDependencies`.
- Window placement follows the screen containing `NSEvent.mouseLocation`. Keep it (multi-monitor regression).

### Testing Requirements
- `make lint` + `make test` (`NotifyToggleDecision`, `ShortcutListPolicy`, `ShortcutRowPolicy`) + Debug and Release compile. Human check with `make run`: every control saves, reads back after reopening and takes effect; notify denied shows the hint; login item needing approval shows its row; undo fields reject `abc` and clamp `0` / `999`; hide the icon and reopen from Finder; the General dot when permission is missing; Shortcuts still records, resolves conflicts and resets; the window opens on the screen with the mouse.

## Dependencies

### Internal
- `Preferences/PreferencesStore`, `Launch/LaunchAtLoginService`, `Permissions/AccessibilityPermissionService`, `Notifications/NotifyToggleDecision`, `Commands/ShortcutListPolicy` · `ShortcutRowPolicy`, `Hotkeys/*`, `Shared/AXMessagingTimeout` (`ResolveTimeoutChoice`), `Shared/AboutContent`, `Shared/BundleVersion`, `UI/*` (next step).

### External
- SwiftUI, Observation, Cocoa.

<!-- MANUAL: -->
