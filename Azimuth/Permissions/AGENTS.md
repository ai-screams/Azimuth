<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# Permissions

## Purpose
Reads and requests Accessibility (AX) permission and points the user at System Settings. Permission is handled **only through the official API**.

## Key Files
| File | Description |
|------|-------------|
| `AccessibilityPermissionService.swift` | `@MainActor`. `currentStatus()` (a cached `AXIsProcessTrusted`), `invalidateCache()`, `requestPrompt()` (`AXIsProcessTrustedWithOptions` with the prompt; returns nothing, because the state immediately after the prompt is the value from before the user acted and is therefore meaningless), `openSystemSettings()` (the Privacy_Accessibility URL), and **`promptAndOpenSettings()`** (the two combined — the single path used by every "open permission settings" button and menu item; the settings window and the status bar had copied the same five lines. Beeping on failure is a UI concern and stays at the call site). Plus `AccessibilityPermissionStatus` (granted/required with its menu and settings-window text) |

## For AI Agents

### Working In This Directory
- **Never bypass permission or defeat a check.** Request permission through the official API and let the user grant it in System Settings.
- When permission seems to "break", the root cause is usually a **code-signing identity mismatch** (an ad-hoc build). Fix it through the signing/build path (`make run`), not in code.

### Testing Requirements
- Run with `make run` (Apple Development signing) so the TCC grant survives. After toggling the state, confirm the 🟢/🟠 indicator updates in the menu and the settings window.

### Common Patterns
- Guard the permission state on both the read and the write boundary (`WindowAccess`), and have the UI re-read it on `didBecomeActive` and when shown.
- **The command path does not re-read the cache to decide.** The cache is invalidated in only two places — app activation and menu opening — so the moment a nudge is needed (pressing a hotkey while the app is inactive and the menu is closed) is exactly when neither has happened. There used to be a defect here where reading `currentStatus()` skipped the nudge. `Commands/CommandFeedbackPolicy` now decides from the **error** (`.resolution(.permissionDenied)`) instead.
- The opposite direction — permission granted while the cache still says `false` — is closed by `WindowCommandExecutor.run`: on a permission denial it invalidates the cache and re-runs once, **only if the fresh value is trusted**. Removing the cache would put a synchronous tccd call on the main thread for every command, so the consumer is what needed fixing, not the cache.

## Dependencies

### Internal
- `StatusBar` and `Settings` (status display), `WindowAccess` (read/write guards).

### External
- ApplicationServices (AX), Cocoa (NSWorkspace).

<!-- MANUAL: -->
