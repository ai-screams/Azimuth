<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-26 -->

# Shared

## Purpose
Coordinate conversion, value types, errors and logging utilities shared across layers.

## Key Files
| File | Description |
|------|-------------|
| `CoordinateSpace.swift` | `@MainActor`. Converts rects between AX (top-left origin, Y down) and Cocoa (bottom-left origin, Y up). The flip is an involution taken against the height of **the display that owns the global origin (0,0)**, so `flip` works in both directions. `axWorkArea(of:)` converts an NSScreen visibleFrame into an AX work area (including a zero-size guard) and is shared by `WorkAreaResolver` and `WindowAccess/DisplayResolver` |
| `BundleVersion.swift` | The `Bundle` extension `displayVersion(prefix:)`. Assembles `CFBundleShortVersionString` (plus the build number) into a display string. Shared by `AboutWindowController` and `GeneralPaneViewController` so the version string is not duplicated. **Legacy branch:** the rule itself is the pure `VersionDisplay.string` (in the harness) — a `209.N` build shows as `Legacy N`; `legacyBuildMajor` must match `LEGACY_BUILD_MAJOR` in `scripts/release.sh` |
| `UpdateFeed.swift` | **Legacy branch.** `UpdateFeed.url(forMajorVersion:)`: macOS 13+ → the main appcast (migration), below → the `legacy-feed` release's appcast. Read by `AppDelegate`'s `SPUUpdaterDelegate.feedURLString(for:)`; `Info.plist` `SUFeedURL` is the legacy feed as the fallback. Pure, in the harness |
| `NSApplication+BringToFront.swift` | `NSApp.bringToFront()` — the one place that activates the app before showing a window or popover (About, Settings, first-run guide). It calls `activate(ignoringOtherApps: true)` because the macOS 14-only `activate()` does not exist on the 13.0 deployment target; the SDK marks the old call *to be* deprecated (no warning). When Apple really deprecates it, add the `if #available` branch here and nowhere else |
| `WindowFrame.swift` | **(in the harness)** `nonisolated`. The `WindowFrame` value type (origin/size → rect) plus `WindowResolutionError` (permission, full screen, subrole, messaging timeout, AX codes and so on, each with an English `userFacingMessage`) |
| `WindowCommandError.swift` | **(in the harness)** `nonisolated`. The top-level command execution error (`resolution` / `workAreaUnavailable` / `notMovable` / `applyFailed` / `noUndoState` / `resolveBudgetExceeded`) plus `userFacingMessage`. The `Result.commandError` extension (the error on failure, nil on success) lives here too — it produces the feedback policy's input |
| `AXMessagingTimeout.swift` | `nonisolated`. Owns the AX messaging timeout values (`resolve` 0.5s / `write` 2.0s) and **the invariant between them**. Also holds `clampedResolve` for Advanced settings (folding 0, negatives, NaN and out-of-range values away safely — AX reads 0 as "return to the 6-second default") and `ResolveTimeoutChoice`, which bundles each value with its display string so an index can never drift. The values are applied in two places, `WindowAccess/FocusedWindowResolver` (entering resolution) and `WindowFrameWriter` (just before a set), but they are defined only here. The whole-resolution budget `resolveBudget(for:)` = `resolveReadCount` (6, the AX round trips a standard window needs) × the user's timeout also lives here — it removed the defect where, as a fixed constant, picking Patient increased silent failures. The file imports only Foundation, so it is in the test harness, and `make test` enforces `write >= resolve` (violating it would make the write-stage raise *lower* the bound, with no compile error) and `resolveBudget(for: resolve) == 3.0` (violating it would diverge from the previous hardcoded constant and silently change behavior for Balanced users). The write-retry budget `writeRetryBudget(for:)` (= `resolveBudget(for:)` + `write`, 5s by default) is here as well — both budgets are measured from the **start of the command**, and `make test` pins their values at all three timeouts (Quick, Balanced, Patient) as literals |
| `LegacySupport.swift` | **Legacy branch.** The one place for macOS 10.13–12 gaps: `LegacySupport.launchAtLogin` (13+) / `.failureNotifications` (10.15+), `NSImage.symbol(_:)` (SF Symbol or nil below 11), `NSImageView.setSymbol(_:)` (hides the view when nil so stack slots collapse), `setTint` (10.14+), and `unsafeAssumeMainActor` — a `MainActor.assumeIsolated` backport; below 10.15 it asserts the main queue and calls the closure through `unsafeBitCast`. Three call sites only (see its SAFETY comment) |
| `Log.swift` | **(in the harness)** Legacy branch: an `os_log` (10.12+) wrapper with the same call shape as `os.Logger` (`Log.app.error("… \(x, privacy: .public)")`), so the 26 call sites are unchanged. `LogMessage` folds `privacy:` into one flag — any interpolation that is not `.public` makes the whole message private. Categories `app`, `windows`, subsystem `com.aiscream.Azimuth` |

## For AI Agents

### Working In This Directory
- `CoordinateSpace` takes its reference height from **the display that owns the origin**, not `NSScreen.screens.first` (on a multi-monitor setup, `first` is not guaranteed to be the main display). Do not break that assumption.
- User-facing strings live in each error enum's `userFacingMessage` (English — they appear verbatim in the status-bar menu and in notifications; localization will come later in one pass). Add a case and its message here for a new failure reason.
- `os.Logger` output does not show up in this environment's `log show`. When diagnosing, use stderr from a direct run, or CGWindowList.

### Testing Requirements
- Pure value and error types. Confirm compilation with `make build`. Coordinate conversion is verified live with `make run`.

### Common Patterns
- Errors are `Equatable` enums so branching stays explicit. Display names and messages are computed properties.

## Dependencies

### Internal
- Nearly every layer depends on this one (errors, coordinates, logging).

### External
- AppKit (NSScreen), CoreGraphics, Foundation, os.

<!-- MANUAL: -->
