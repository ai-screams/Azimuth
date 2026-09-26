<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# Permissions

## Purpose
Reads and requests Accessibility (AX) permission and points the user at System Settings. Permission is handled **only through the official API**.

## Key Files
| File | Description |
|------|-------------|
| `AccessibilityPermissionService.swift` | `@MainActor`. `currentStatus()` (a cached `AXIsProcessTrusted`), `invalidateCache()`, `openSystemSettings()` (the Privacy_Accessibility URL, then the Security root as a fallback — best-effort deep links, not a public contract), and **`requestAccess(preferences:)`** — the single path behind every "open permission settings" button and menu item. It asks `AccessibilityRequestPolicy` whether to show the macOS alert or open System Settings, **never both** (doing both opened Settings before the user answered the alert). On the alert path it records the attempt first, brings Azimuth to the front, and requests the prompt on the next run loop turn (activation is not guaranteed to be immediate). Returns true when it dispatched the prompt or opened Settings — not that the alert appeared or access was granted; beeping on false stays at the call site. Plus `AccessibilityPermissionStatus` (granted/required with its menu and settings-window text) |
| `AccessibilityRequestPolicy.swift` | Pure, harness-tested. `decide(isTrusted:didAttemptPrompt:)` → `.systemPrompt` only when untrusted and never attempted, else `.openSettings` (TCC is observed to show the alert once per app, and there is no API to tell never-asked from denied). `initialAttemptFlag(recorded:didCompleteFirstRun:)` — installs from before this rule, which prompted on every click, count as attempted so their first click does not go dead; `PreferencesStore.init` applies it once, **before** first-run onboarding sets `didCompleteFirstRun` |

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
