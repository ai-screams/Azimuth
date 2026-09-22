<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# StatusBar

## Purpose
The menu-bar status item and its menu. Shows permission state, opens settings, quits, and provides the DEBUG diagnostics and command submenu.

## Key Files
| File | Description |
|------|-------------|
| `StatusBarController.swift` | `@MainActor`, `NSMenuDelegate`. A compact SF Symbol status icon (`macwindow.on.rectangle` when permission is granted, `exclamationmark.triangle` when it is needed). The menu holds: permission state / open Accessibility settings / the last command failure reason (an informational row fed by the `lastFailureText` closure that AppDelegate injects, hidden when there is no failure) / Check for Updates… / Open Settings (`⌘,`) / Quit (`⌘q`). Under DEBUG it also offers focused-window identification and a submenu of all 34 commands (`WindowCommand.menuCommands`) |

## For AI Agents

### Working In This Directory
- The permission state and the last-failure row refresh in `menuWillOpen` (permission also refreshes on app activation through `refreshPermissionState`).
- Wrap DEBUG-only diagnostics in `#if DEBUG` so they never reach the RELEASE menu.
- The menu-bar icon is an SF Symbol (a template image), so it needs no asset. With a crowded menu bar and multiple displays, macOS may hide the item — that is outside the app's control.

### Testing Requirements
- Use `make run` to confirm the menu-bar item appears, the permission color changes, and the DEBUG command submenu works.

### Common Patterns
- Commands run through `Commands/WindowCommandExecutor.run`, the same path as hotkeys (one path only). On failure: beep and log.

## Dependencies

### Internal
- `Permissions/AccessibilityPermissionService`, `Commands/WindowCommandExecutor` · `WindowCommand`, `WindowAccess/FrontmostAppTracker` · `FocusedWindowResolver` · `WindowUndoStore` · `SnapStateStore`, `Shared/Log`.

### External
- Cocoa (NSStatusBar / NSMenu), os.

<!-- MANUAL: -->
