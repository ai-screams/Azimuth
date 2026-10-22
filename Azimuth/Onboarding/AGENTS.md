<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-10-23 -->

# Onboarding (first-run guide and practice window)

## Purpose
On first launch, a popover anchored to the status-bar icon introduces the menu-bar residency and the global hotkeys, and opens the Settings window's General pane (Permissions) when Accessibility permission is missing. `AppDelegate.showFirstRunOnboardingIfNeeded()` shows it exactly once, gated by the `PreferencesStore.didCompleteFirstRun` flag. A practice window (#176) then lets the user try Left 1/2, Maximize and Undo on a sample window.

## Key Files
| File | Description |
|------|-------------|
| `FirstRunGuidePresenter.swift` | An `NSPopover` (.transient) presenter. In an `.accessory` app, click-outside dismissal works only while the app is active, so it calls `NSApp.bringToFront()` (`Shared/NSApplication+BringToFront`) right before showing. Both close paths (the default button and clicking outside) are torn down together in `popoverDidClose` |
| `FirstRunGuideView.swift` | SwiftUI content hosted by the popover through `NSHostingController` (#176): app-icon header, guidance rows, a Launch at login checkbox (reverts and beeps if registration fails) and the default button. System colors only, so light and dark follow. When permission is missing, the default button reads "Open Settings…"; with permission the buttons are "Not Now" and "Try the Shortcuts" (opens the practice window) |
| `PracticeSession.swift` | Pure, in the harness. `PracticeStep` (leftHalf → maximize → undo → done, each with its `WindowCommand`) and `PracticeSession`: the target frame for a command (`FrameCalculator`, AX coordinates), its own Undo history (only moves that change the frame, capped at 20), and `didMove`, which advances only when the command is this step's and the actual frame is within 2 pt of the target |
| `PracticeWindowController.swift` | `@MainActor`. The "Practice Shortcuts" window (520×360, centered on the screen with the mouse) and `PracticeModel` (`@Observable`). `handle(_:)` takes a hotkey command only while the window is visible, key and the app active, moves the window itself with `setFrame` and returns true; otherwise false and the command goes to other apps as usual. The hosting controller uses `sizingOptions = []` so content changes never resize the window away from the frame being tested. The keycaps show only shortcuts that actually registered (`AppDelegate.boundShortcut` drops registration failures), and the no-op beep follows the sound feedback setting. `show()` always restarts at step 1 |
| `PracticeView.swift` | SwiftUI content: "Try it · N of 3", the command glyph, the instruction, the bound shortcut as keycaps (or a hint when unbound), progress dots and Skip; the last step is "You're set." with Close |

## For AI Agents
- The "shown" flag is recorded **when the decision to show is made**, not when the popover closes (this prevents a re-display loop after a crash). Preserve that property if you change the flow.
- If the status-bar button cannot be obtained (no room in the menu bar), fall back to opening the Settings window when permission is missing — see `AppDelegate.showFirstRunOnboardingIfNeeded()`.
- The practice window is Azimuth's own window, so the AX path (`FrontmostAppTracker`) skips it. `AppDelegate.runHotkeyCommand` asks `practiceWindowController.handle` first; keep that order and keep `handle` returning false when the window is not in front.
- Entry points: the popover's "Try the Shortcuts", the status menu's "Practice Shortcuts…", Settings General → Practice → "Start…", and once automatically after permission is granted (`PreferencesStore.practiceGuidePending`, set on a first run without permission, consumed in `openPendingPracticeGuide` on activation).
- Testing: `PracticeSession` is in `make test` (`Tests/CommandEngineTests+Onboarding.swift`); the views and controllers are not. To look at it, run `defaults delete <bundle-id> didCompleteFirstRun` and then `make run`.

## Dependencies
- Internal: `LaunchAtLoginService` (the checkbox), `AccessibilityPermissionService` (permission state), `StatusBarController.statusButton` (the anchor), `PreferencesStore.didCompleteFirstRun` (the one-shot flag) and `practiceGuidePending`, `Commands/FrameCalculator`, `Shared/CoordinateSpace`, `UI/CommandGlyphView` · `KeycapsView`.
- External: AppKit, SwiftUI.
