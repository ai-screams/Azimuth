<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-10-22 -->

# Onboarding (first-run guide)

## Purpose
On first launch, a popover anchored to the status-bar icon introduces the menu-bar residency and the global hotkeys, and opens the Settings window's General pane (Permissions) when Accessibility permission is missing. `AppDelegate.showFirstRunOnboardingIfNeeded()` shows it exactly once, gated by the `PreferencesStore.didCompleteFirstRun` flag.

## Key Files
| File | Description |
|------|-------------|
| `FirstRunGuidePresenter.swift` | An `NSPopover` (.transient) presenter. In an `.accessory` app, click-outside dismissal works only while the app is active, so it calls `NSApp.bringToFront()` (`Shared/NSApplication+BringToFront`) right before showing. Both close paths (the default button and clicking outside) are torn down together in `popoverDidClose` |
| `FirstRunGuideView.swift` | SwiftUI content hosted by the popover through `NSHostingController` (#176): app-icon header, guidance rows, a Launch at login checkbox (reverts and beeps if registration fails) and the default button. System colors only, so light and dark follow. When permission is missing, the default button reads "Open Settings…" |

## For AI Agents
- The "shown" flag is recorded **when the decision to show is made**, not when the popover closes (this prevents a re-display loop after a crash). Preserve that property if you change the flow.
- If the status-bar button cannot be obtained (no room in the menu bar), fall back to opening the Settings window when permission is missing — see `AppDelegate.showFirstRunOnboardingIfNeeded()`.
- Testing: this is a UI-only layer, so it is not covered by `make test`. To look at it, run `defaults delete <bundle-id> didCompleteFirstRun` and then `make run`.

## Dependencies
- Internal: `LaunchAtLoginService` (the checkbox), `AccessibilityPermissionService` (permission state), `StatusBarController.statusButton` (the anchor), `PreferencesStore.didCompleteFirstRun` (the one-shot flag).
- External: AppKit, SwiftUI.
