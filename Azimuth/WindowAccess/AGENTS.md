<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# WindowAccess

## Purpose
The layer that touches the Accessibility (AX) API directly. It resolves "which app, which window", reads and writes window frames, and computes undo state and screen work areas. The command engine (`Commands/`) manipulates real windows through this layer.

## Key Files
| File | Description |
|------|-------------|
| `FrontmostAppTracker.swift` | `@MainActor`. Tracks the most recently activated non-Azimuth app (via a `didActivateApplication` observer). `targetApplication` keeps the "which app does a command act on" policy in one place |
| `FocusedWindowResolver.swift` | `@MainActor`. Resolves the target app's `kAXFocusedWindowAttribute` into a `ResolvedWindow`. Sets a `resolveTimeout` messaging timeout on the app and window AX elements (default `Shared/AXMessagingTimeout.resolve`, 0.5s; when the user adjusts it in Advanced settings, AppDelegate injects the clamped value) and aborts immediately on failure. Gate and frame reads stop rather than continue on `.cannotComplete` (a timeout) — this is fail-closed, because flattening a read failure to nil under a short timeout would let a write reach a full-screen window. Guards for permission, full screen (the private `AXFullScreen` attribute), minimized state and subrole (`kAXStandardWindowSubrole`), plus AX error mapping |
| `AXAttribute.swift` | `nonisolated`. A thin wrapper over AX attributes — reads (string/bool/element/point/size) and writes (`set`: bool/point/size). For callers that must distinguish "there is no value" from "the app did not answer", it also offers error-carrying variants (`stringValue` / `boolValue` / `pointValue` / `sizeValue`); the thin wrappers flatten every error to nil. The one place a narrow force-cast is allowed (with a `swiftlint:disable` comment) |
| `FrameWriteRequest.swift` | `@MainActor` value bundle holding everything one frame write needs (target, `ResolvedWindow`, work area, anchor, and the command's start time). It carries an `AXUIElement`, so it stays out of the harness — only the decision made from this request was extracted, as `WriteRetryPolicy` |
| `WindowFrameWriter.swift` | `@MainActor`. AX position/size writes. The input is a single `FrameWriteRequest` (target, window, work area, anchor and the **command start time**), and the retry decision belongs to the pure `Commands/WriteRetryPolicy` — the budget must be measured from the start of the command, not from entering the write, so that the freeze already spent on resolution and suppression counts against it (audit H-3). Requires permission only for the axes that actually change and writes only those axes (M-3); when shrinking, writes size before position (so the old larger size cannot spill onto the neighboring monitor); keeps the pinned corner against the app's actual size via an explicit `anchor` (M-4), then verifies and retries once. **Edge reanchor (#100):** after the last size write and the final read, the pure `Commands/EdgeReanchorPolicy` decides whether a `.workAreaEdges` window that ended up smaller or larger than the target (beyond 8pt) sits off the edge it should touch; if so the writer writes position once more (checking position settability lazily for resize-only commands, and skipping — keeping the old success — when it is not settable), overwrites `positionError` with that result, and re-reads `achieved` with no fallback (nil on failure). This is the one exception to "write only the changed axes", and the only case where a constrained app can show a two-step move. Returns a `FrameApplyResult` carrying `achieved` on both success and failure (success/failure comes from the write result; whether anything changed is the executor's call — H-1). Animation suppression is delegated to `AnimationSuppressor`. The messaging timeout is raised to `AXMessagingTimeout.write` (2s) only right before the actual position/size `set` — the justification for that longer bound is the `.transient` (silent skip) mapping, which only `set` has; the preceding `isSettable` surfaces as `.notMovable` to the user, so failing fast under the short bound is better |
| `AnimationSuppressor.swift` | `@MainActor`. Turns off the target app's `AXEnhancedUserInterface` / `AXManualAccessibility` for the duration of a write and restores them 0.25s after the last input (debounced per PID). **PID reuse is defended against by `NSWorkspace.didTerminateApplicationNotification`** — `AXUIElementCreateApplication(pid)` returns a CFEqual element regardless of who owns the pid now, so element identity cannot filter it. Skipped entirely while VoiceOver is running. This removes the primary cause of flicker |
| `WindowUndoStore.swift` | `@MainActor`. Stores one step of previous frame per window (capacity 64, LRU). Identifies the `AXUIElement` by `CFEqual` / `CFHash` and includes the pid in the key (so a reused element from a closed window cannot be mistaken for the same window — the value is a single `CGRect`, the same key design as `SnapStateStore`). `clearAll` is called on display reconfiguration |
| `SnapStateStore.swift` | `@MainActor`. Stores per-window snap state (`SnapRecord`: edge + the frame at snap time) with capacity 64 and LRU, using the same key design as the undo store. snapThrow uses it to recognize a constrained app as "already snapped" and to invalidate that when the window is moved externally (H-2). `clearAll` is called on display reconfiguration |
| `WorkAreaResolver.swift` | `@MainActor`. Returns, in AX coordinates, the `visibleFrame` of the screen the AX window frame overlaps most (multi-monitor aware) |
| `DisplayResolver.swift` | `@MainActor`. Resolves the adjacent-display target for snapThrow and moveToDisplay. Decides which screen to throw to from the window frame and the edge direction, and hands it to `WindowCommandExecutor` |
| `NSScreen+BestMatch.swift` | An `NSScreen` extension returning the screen that overlaps a given **Cocoa**-coordinate rect the most (`bestMatch(forCocoaRect:)`) — both callers (`WorkAreaResolver`, `DisplayResolver`) go through `CoordinateSpace.axToCocoa` first. The selection rules (area → contains center → smaller displayID) live in the pure `Commands/DisplayGeometry.bestMatchIndex`; this file only maps `NSScreen` to `ScreenCandidate` and handles the no-overlap fallback (main → first screen) |

## For AI Agents

### Working In This Directory
- Keep permission guards on **both the read and the write side** (defensively, so nothing depends on call order). Never remove or bypass a permission check.
- If setting the messaging timeout on an app or window AX element fails, abort resolution with `messagingTimeoutConfigurationFailed` rather than continuing under the 6-second default.
- Full screen cannot be distinguished by subrole, so check the private `AXFullScreen` attribute **before** the subrole check (preserving existing behavior).
- Work in AX coordinates (top-left origin). Use `Shared/CoordinateSpace` when a screen or Cocoa conversion is needed.

### Testing Requirements
- This layer needs a real AX grant, so it is verified **live with `make run`** (signed build) instead of by unit tests. The pure calculations were split into `Commands/FrameCalculator` and are covered by `make test`.

### Common Patterns
- `Result<_, WindowResolutionError>` / `Result<CGRect, WindowCommandError>` make the failure reason explicit.
- `ResolvedWindow` (element / appElement / subrole / pid / frame) is the single carrier for a resolution result. The writer uses `appElement` for animation suppression.

## Dependencies

### Internal
- `Permissions/AccessibilityPermissionService` (permission), `Shared/WindowFrame` · `WindowResolutionError` · `CoordinateSpace`, `Commands/WindowCommandError`.

### External
- ApplicationServices (AX), AppKit (NSScreen / NSWorkspace / NSRunningApplication).

<!-- MANUAL: -->
