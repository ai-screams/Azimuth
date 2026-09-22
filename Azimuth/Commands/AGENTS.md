<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# Commands

## Purpose
The command engine. It holds **what** to do (the command model), **where** to do it (pure geometry), and the actual **execution orchestration**. The model and the geometry are pure logic with no AppKit/AX dependency, so `Tests/` compiles them standalone with `swiftc`.

## Key Files
| File | Description |
|------|-------------|
| `CommandPrimitives.swift` | `nonisolated` building-block value types: `Axis` / `Fraction` / `Slot` / `AbsolutePlacement` / `MoveDirection` / `RelativeAnchor` / `SnapEdge` (display names and stable tokens) plus `FrameAnchor` (which corner to pin) and `SnapRecord` (per-window snap state). Split out of `WindowCommand.swift` to keep that file from bloating |
| `WindowCommand.swift` | `nonisolated` command model: `WindowCommand` (maximize/absolute/snapThrow/moveToDisplay/move/relativeHalf/relativeTwoThird/undo) + `CommandGroup` (core/halves/thirds/twoThirds/move/relative/display) + a per-command `frameAnchor` + identifier reverse lookup + the `menuCommands` list (34 entries) |
| `FrameCalculator.swift` | `nonisolated` pure geometry. Computes the target frame from AX-coordinate inputs (current, workArea): absolute placement (axis-independent), moves (keep current size, clamp to the work area), relative halves and two-thirds (pin an edge relative to the current frame), snapThrow/moveToDisplay support (`halfRect`, `isAlreadySnapped`, `displayMoveRect`), anchor math (`anchoredOrigin`), gapped maximize (`gappedWorkArea`), and constrained-app / usable-frame checks (`isConstrained`, `isUsableFrame`) |
| `FrameApply.swift` | `nonisolated` pure predicates. Collects the geometry decisions that do not depend on interpreting AX results: `changed` (did achieved move from pre — for Undo), `reached` (did we hit the target — for retry and restore checks), `movesOrigin` / `resizesSize` (per-axis change — for permission and write minimization). The writer passes AX results and read frames in as values |
| `CommandOutcomePolicy.swift` | `nonisolated` pure state-commit policy. Takes the pre-command frame, the target frame and the actual AX result, and decides whether to record Undo and whether to keep/record/clear the snap state. Uses `target` to tell an intended no-op apart from the case where AX returned success but the app ignored the write |
| `CommandPlanPolicy.swift` | `nonisolated` pure planning policy. Takes the command, current frame, work area, snap record and adjacent work area (`CommandPlanInput`) and decides the target frame plus the edge the window will be snapped to afterwards (`CommandPlan`). The snapThrow state machine lives here (not snapped → snap; already snapped → throw to the opposite half of the adjacent display; no adjacent display → stay put), as does the moveToDisplay destination. The executor looks the adjacent work area up via `WindowCommand.adjacentEdge` and passes it in as a value |
| `DisplayGeometry.swift` | `nonisolated` pure geometry answering two questions: which screen is the window on now (`bestMatchIndex(window:candidates:)` — largest intersection area, ties broken by which screen contains the center, then by smaller displayID; input is `ScreenCandidate` (frame + displayID), the return is an index into the original `candidates`), and which neighbor of that screen to move to (`selectAdjacentIndex(current:candidates:window:edge:)` — direction, perpendicular/primary gaps, distance, overlap). The AX layer (`WindowAccess/NSScreen+BestMatch`, `DisplayResolver`) only maps `NSScreen` to values |
| `WriteRetryPolicy.swift` | `nonisolated` pure retry decision. Elapsed time, budget, verification result (reached / short / read failed) and which axes change → whether to retry position and size individually. Elapsed is measured from the **start of the command**, so the time spent resolving and suppressing counts against the budget. Imports Foundation only |
| `ShortcutRowPolicy.swift` | `nonisolated` pure row-display decision (settings Shortcuts tab). Binding, override, group/command checkboxes, effective enablement, conflict and registration failure → recorder string, the checkbox's two axes (on and enabled are different axes), Reset, name dimming, the modified dot, and the badge meaning. **A duplicate outranks a registration failure**, and no badge is shown when the command is not effectively enabled. Wording and color are the view's choice. No imports |
| `ShortcutListPolicy.swift` | `nonisolated` pure display decision (settings Shortcuts tab). Search query and the groups the user expanded → a per-group `ShortcutGroupDisplay` (header visible / expanded / separator). While searching, matching groups expand automatically, so results are never hidden behind a collapsed group. Imports Foundation only |
| `CommandFeedbackPolicy.swift` | `nonisolated` pure decision. Command result + user settings (sound/notification) + session flag → `CommandFeedback` (last-failure `clear`/`keep`/`set`, beep, notification, permission nudge). Deciding the nudge **from the error** removed the defect where a stale `AccessibilityPermissionService` cache skipped it. The error switch is exhaustive with no `default:` — a new case breaks the build and forces a decision about how it appears to the user. Imports Foundation only |
| `WindowCommandExecutor.swift` | `@MainActor` orchestration. Resolve the window → resolve the work area → read the snap record and adjacent work area → decide the target via `CommandPlanPolicy` → write through AX (with `anchor`) → record Undo and commit snap state as `CommandOutcomePolicy` decided. Maps `FrameApplyResult` to `Result<CGRect, WindowCommandError>` |

## For AI Agents

### Working In This Directory
- `CommandPrimitives.swift`, `WindowCommand.swift`, `FrameCalculator.swift`, `FrameApply.swift`, `DisplayGeometry.swift`, `CommandOutcomePolicy.swift`, `CommandPlanPolicy.swift`, `WriteRetryPolicy.swift`, `ShortcutListPolicy.swift`, `ShortcutRowPolicy.swift` and `CommandFeedbackPolicy.swift` **must not import AppKit or AX** (stay pure; CoreGraphics is fine). The reason is **not** "it breaks the harness" — the harness compiles files that import AppKit without trouble (`Hotkeys/CarbonModifier.swift` is in it and does exactly that). The rule here is **layering discipline**: the command model, the geometry and the policies must not know about the UI. The real boundary that makes a type unrunnable is carrying an `AXUIElement` (see `Tests/AGENTS.md`).
- To add a command: a case plus `displayName` in `WindowCommand`, a branch in `FrameCalculator.targetFrame`, and — if it belongs there — entries in `menuCommands` and the `Hotkeys/HotkeyPreset` bindings.
- Every frame is in **AX coordinates** (top-left origin). Cocoa conversion happens at the caller (`WorkAreaResolver`).

### Testing Requirements
- `make test` (`Tests/CommandEngineTests*.swift`) covers absolute placement, axis composition, moves, relative halves, relative two-thirds, the snapThrow state machine (snap / throw / stay put), displayMove, gapped maximize, fixed-width detection, current-screen selection (area, center, displayID ties), adjacent-display selection, the AX outcome commit policy, the write-retry decision, the command model (34 entries), shortcut list display (search and collapse), the row-display truth table (the checkbox's two axes and badge priority), failure feedback (beep, notification, permission nudge), and every user-facing string. When you change geometry or a policy, add cases to the matching domain extension file. Pure-logic line coverage is gated by `make coverage` (≥90%).

### Common Patterns
- Move clamping: when the window is larger than the work area (`upper < lower`), pin it to the top-left (`lower`).
- After applying through AX, `WindowCommandExecutor` records a one-step restore point only when `CommandOutcomePolicy` says the window actually changed or may have. An undo entry is removed only once the target frame is confirmed reached.

## Dependencies

### Internal
- `WindowAccess/FocusedWindowResolver` (window resolution), `WindowAccess/WindowFrameWriter` (AX writes), `WindowAccess/WorkAreaResolver` (work areas), `WindowAccess/WindowUndoStore`, `WindowAccess/FrontmostAppTracker`, `Shared/WindowCommandError`.

### External
- CoreGraphics (model and geometry), Cocoa (the executor).

<!-- MANUAL: -->
