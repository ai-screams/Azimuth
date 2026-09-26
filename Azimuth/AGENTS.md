<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# Azimuth (app source)

## Purpose
The app source root. From the programmatic AppKit entry (`main.swift`), `AppDelegate` assembles every component: the status-bar item, global hotkeys, the settings window, and permission tracking. Split into feature subdirectories.

## Key Files
| File | Description |
|------|-------------|
| `main.swift` | Standard entry point with no storyboard. Uses `MainActor.assumeIsolated` to attach `AppDelegate` to `NSApplication` explicitly, then runs |
| `AppDelegate.swift` | Composition root. Owns the tracker, undo store, hotkey service, preferences, settings window and status bar; `applicationDidFinishLaunching` installs them, reloads hotkeys and registers observers. Dispatches hotkey commands (`runHotkeyCommand`). Creates and owns Sparkle's `SPUStandardUpdaterController` and injects a "Check for Updates…" closure into the settings window so the UI never imports Sparkle directly |
| `MainMenuBuilder.swift` | Builds the App/Edit/Window main menu in code. The "Check for Updates…" item receives the Sparkle updater controller as a target/selector pair (MainMenuBuilder itself imports only AppKit) |
| `Info.plist` | Custom Info.plist (`GENERATE_INFOPLIST_FILE=NO`). Holds the Sparkle keys (`SUFeedURL`, `SUPublicEDKey`) and the version variables (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` / `AZIMUTH_LSUIELEMENT`). This file is copied into the bundle instead of a generated plist |
| `GeneralPaneViewController.swift` | The settings window's **General tab** (properties, lifecycle, state refresh): Permissions / Behavior / Updates cards. The Updates card holds `versionLabel` (current version) and `checkForUpdatesButton` (calls the injected Sparkle closure). Fonts and subview factories live in `GeneralPane+Layout.swift`, `@objc` actions in `GeneralPane+Actions.swift`. The scroll-view and stack skeleton comes from `Settings/SettingsPaneScaffold`. The settings window has three toolbar tabs (General/Shortcuts/Advanced — see `Settings/AGENTS.md`); this file is one of those panes |
| `AboutWindowController.swift` | Custom About window (icon, name, version, tagline + Homepage / Report an Issue / Sponsor / Ko-fi link buttons). The version is read from the bundle via `Shared/BundleVersion`, so it always matches the release |
| `UpdateVersionDisplayer.swift` | `nonisolated` Sparkle adapter (`SPUStandardUserDriverDelegate` + `SUVersionDisplay`) that routes the standard update window's version strings through `Shared/UpdateVersionText`. Separate from `AppDelegate` so a `@MainActor` type does not adopt Sparkle's unannotated ObjC protocols; `AppDelegate` retains it (Sparkle holds delegates weakly) and passes it as `userDriverDelegate`. The optional selectors are checked against real Sparkle by `scripts/sparkle-adapter-check.sh` (CI) — a misspelled Swift name only warns and silently falls back to "1.7.2". The no-relaunch "Update Installed" alert bypasses the formatter (unused by Azimuth) |
| `FlippedView.swift` / `NSButton+Rounded.swift` | Shared helpers: a flipped scroll document view, and a `.rounded` button factory |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Commands/` | Command model + geometry + execution orchestration (see `Commands/AGENTS.md`) |
| `WindowAccess/` | AX app/window resolution, frame reads and writes, undo, work areas (see `WindowAccess/AGENTS.md`) |
| `Hotkeys/` | Carbon global hotkeys + presets (Standard/Vim) (see `Hotkeys/AGENTS.md`) |
| `Shared/` | Coordinate conversion, value types, errors, logging (see `Shared/AGENTS.md`) |
| `Permissions/` | Accessibility permission state and requests (see `Permissions/AGENTS.md`) |
| `Preferences/` | UserDefaults wrapper (see `Preferences/AGENTS.md`) |
| `Settings/` | Settings window: window controller + toolbar tab container + Shortcuts/Advanced panes + shared skeleton (see `Settings/AGENTS.md`) |
| `Onboarding/` | First-run popover anchored to the status bar (see `Onboarding/AGENTS.md`) |
| `StatusBar/` | Menu-bar status item and menu (see `StatusBar/AGENTS.md`) |
| `Launch/` | Launch at login via SMAppService (see `Launch/AGENTS.md`) |
| `Notifications/` | Command-failure notifications (opt-in, UserNotifications) (see `Notifications/AGENTS.md`) |
| `Assets.xcassets` | App icon and accent color. The menu-bar icon is an SF Symbol, so it needs no asset |

## For AI Agents

### Working In This Directory
- Create and inject new dependencies from `AppDelegate`. Components are wired by constructor injection (for example the settings window receives `PreferencesStore` / `LaunchAtLoginService`).
- If you touch the entry or the wiring (`main.swift` / `AppDelegate`), confirm **a window actually appears**. `@main` alone does not attach the delegate (there is no storyboard).
- DEBUG builds use activation policy `.regular` and show the settings window at launch; RELEASE uses `.accessory` (menu bar only). The DEBUG bundle id is `com.aiscream.Azimuth.debug`, which keeps its TCC grant and UserDefaults domain separate from an installed release copy in /Applications (this is what prevents grant clashes). Debug `defaults` / `tccutil` commands must use the `.debug` id.

### Testing Requirements
- `make build` + `make lint` + `make test`. Verify permission-dependent behavior with `make run` (signed build).

### Common Patterns
- `@MainActor` by default. Pure value/logic types are `nonisolated` (for example the enums and structs in `Commands` and `Shared`).
- Command execution funnels through one path, `Commands/WindowCommandExecutor.run(_:tracker:undoStore:snapStore:)`, shared by hotkeys and the DEBUG menu.

## Dependencies

### Internal
- `AppDelegate` → every subsystem. See `Commands/AGENTS.md` for the execution path.

### External
- AppKit, ApplicationServices, Carbon.HIToolbox, ServiceManagement, os (Logger).
- **Sparkle 2** (SPM, 2.9.3): `AppDelegate` creates `SPUStandardUpdaterController` (`startingUpdater: true`) to begin automatic feed checks. The "Check for Updates…" item appears in three places — the App menu (`MainMenuBuilder`), the status-bar menu (`StatusBarController`) and the Settings Updates card (`GeneralPaneViewController`) — and `AppDelegate` injects a closure or target/selector into each, so no individual component imports Sparkle. The feed URL and EdDSA public key (`SUPublicEDKey`) live in `Azimuth/Info.plist`.

## Sparkle Auto-Update

| Component | Role |
|-----------|------|
| `AppDelegate.updaterController` | Owns and starts `SPUStandardUpdaterController`. The "Check for Updates…" target |
| `MainMenuBuilder` | The App menu's "Check for Updates…" item — receives target/selector as arguments |
| `StatusBarController.checkForUpdates` | The status-bar menu's "Check for Updates…" — target/selector pair injected by `AppDelegate` |
| `GeneralPaneViewController.checkForUpdates` | The Settings Updates card button closure — injected by `AppDelegate` |
| `Azimuth/Info.plist` | `SUFeedURL` (fixed appcast URL) + `SUPublicEDKey` (EdDSA public key) |

<!-- MANUAL: -->
