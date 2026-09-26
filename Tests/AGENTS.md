<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-26 -->

# Tests

## Purpose
Regression tests for the command engine's **pure logic**. Instead of an Xcode test target, they are compiled and run directly with `swiftc`, which gives a fast, dependency-free safety net.

## Key Files
| File | Description |
|------|-------------|
| `CommandEngineTests.swift` | The `@main` executable test plus the shared `expect*` helpers. Calls each domain's test functions and exits non-zero on failure |
| `CommandEngineTests+Frames.swift` | Frame calculation: absolute placement, axis-independent composition, moves, relative shrink, gapped maximize |
| `CommandEngineTests+Displays.swift` | Snap detection, displayMove, current-screen selection (`bestMatchIndex`: area, the 50:50 center rule, displayID ties, the deadband, the non-transitive three-screen case, and the original index) and adjacent-display selection |
| `CommandEngineTests+Plan.swift` | `CommandPlanPolicy`. The snapThrow state machine (not snapped → snap; already snapped → throw; no adjacent display → stay put), the moveToDisplay destination, the delegation boundary and `WindowCommand.adjacentEdge`, each across all four directions. Assertions go only through `expectPlan` (whole-struct equality) |
| `CommandEngineTests+Apply.swift` | anchor, FrameApply, CommandOutcomePolicy and WriteRetryPolicy (the retry decision and its budget boundary). Verifies the state commit for partial AX application, ignored successful writes and a failed final read, all from values |
| `CommandEngineTests+Model.swift` | Command groups, primitive strings, the command model, identifiers and helpText exhaustively, plus the failure-feedback decision and the row-display truth table (`ShortcutRowPolicy`: the checkbox's two axes and badge priority) |
| `CommandEngineTests+Legacy.swift` | **Legacy branch.** `LogMessage` privacy folding (all public / unannotated / mixed / explicit private) and one pass through each log level; update-feed choice per macOS major version; `VersionDisplay` (`209.N` → `Legacy N`, other builds unchanged) |
| `CommandEngineTests+Updates.swift` | Sparkle update-window version text (`UpdateVersionText`), incl. Legacy 1→2 and legacy→main migration pairs. Same file as main |
| `CommandEngineTests+Hotkeys.swift` | The shortcut binding layer. Per-preset key assignment, overrides, the enabled filter, conflict detection, display strings, Codable round-trips and Carbon modifiers |
| `CommandEngineTests+Permissions.swift` | Accessibility request path: prompt only on the first untrusted request, Settings afterwards; the migration default for upgrades; `PreferencesStore` migration timing (a new install still prompts after onboarding sets `didCompleteFirstRun`) and its defaults, persistence, shortcut and enable-state storage, timeout clamping. Same file as main |

## For AI Agents

### Working In This Directory
- What can be verified here is **logic that can be built as a value**. `scripts/harness-sources.sh` is the single source for the compile list (`HARNESS_SRC`, `HARNESS_TESTS`) and both `test.sh` and `coverage.sh` source it, so a new file is added in **one place**.
- **The bar is not "does it import AppKit".** An older version of this document claimed that adding an AppKit/AX import breaks the harness; that is **not true** — `Hotkeys/CarbonModifier.swift` compiles and runs in the harness with `import AppKit`. The real constraint is a type that **carries an `AXUIElement`**: it cannot be built as a value, so it cannot be run. That is why the AX layer extracts its decisions as values-in / values-out functions and includes only those (`CommandOutcomePolicy` and `ShortcutListPolicy` are examples).
- When geometry or a command changes, add cases here. The work-area fixture is `CGRect(x: 0, y: 25, w: 1920, h: 1055)`.

### Testing Requirements
- Run: `make test` (= `./scripts/test.sh`). Identical to CI's "Command-engine tests" step.
- Coverage: `make coverage` (= `./scripts/coverage.sh`). **Pure-logic line coverage targets ≥ 90%** (below that it exits non-zero; adjust with `COVERAGE_MIN`). Add cases alongside new or changed logic to hold that line. The AppKit/AX layer is excluded from measurement and verified live instead.
- Registering a new test function in `CommandEngineTests.main()` is required — this harness is not XCTest, so an unregistered test compiles and "passes" without ever running.

### Common Patterns
- Compare frames with the `expect(label, got, want)` helper plus `approx` (0.001 floating-point tolerance). `expectPlan` compares a whole `CommandPlan` exactly. On success it prints `PASS — all N checks`.

## Dependencies

### Internal
- `HARNESS_SRC` in `scripts/harness-sources.sh` is the single source for what gets compiled (the pure files under `Commands/`, plus `Shared/AXMessagingTimeout` and the binding layer in `Hotkeys/`).

### External
- CoreGraphics, Foundation.

<!-- MANUAL: -->
