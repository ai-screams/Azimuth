<!-- Generated: 2026-06-19 | Updated: 2026-09-25 -->

# Azimuth

## Purpose
Azimuth is a macOS menu-bar **window manager** (in the Magnet/Rectangle family). It uses the Accessibility (AX) API to identify another app's focused ordinary window, then halves / thirds / maximizes / moves / relatively resizes / undoes it from a global hotkey or a menu command. Swift + AppKit, programmatic entry with no storyboard (`Azimuth/main.swift`). Xcode project (objectVersion 77, file-system synchronized group).

## Key Files
| File | Description |
|------|-------------|
| `Makefile` | `build` (ad-hoc compile, CI only) · `run` (Apple Development signed, for permission testing) · `lint` · `format` · `test` · `coverage` (≥90% gate) · `secrets` · `release` · `install-hooks` |
| `README.md` | Project overview (install, shortcuts, command behavior, sponsorship) |
| `CLAUDE.md` | Top-level orientation for AI agents (build, rules, conventions, docs/funding, environment gotchas). Details live in the per-directory `AGENTS.md` |
| `SECURITY.md` · `CONTRIBUTING.md` · `SUPPORT.md` · `CODE_OF_CONDUCT.md` | GitHub community health files (security reporting, contribution guide, support, code of conduct) |
| `RELEASING.md` | Release procedure |
| `LICENSE` · `NOTICE` | Apache-2.0 license + notices |
| `Azimuth.xcodeproj` | Xcode project. Non-sandboxed, `DEVELOPMENT_TEAM=7K6MK3KP9K`, `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, deployment target macOS 13.0 |
| `.swiftlint.yml` | SwiftLint strict configuration |
| `.swiftformat` | SwiftFormat configuration (`--lint` in pre-commit and CI) |
| `.gitleaks.toml` | Secret-scan rules |
| `.gitignore` | Excludes `.docs/`, `.omc/`, and friends |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Azimuth/` | All app source (see `Azimuth/AGENTS.md`) |
| `Tests/` | Pure-logic regression tests for the command engine (see `Tests/AGENTS.md`) |
| `scripts/` | build/run/lint/format/test/coverage/secret-scan/release shell scripts (see `scripts/AGENTS.md`) |
| `docs/` | GitHub Pages source: landing page and manual (bilingual EN/KO) (see `docs/AGENTS.md`) |
| `.github/` | GitHub Actions CI + governance (FUNDING/CODEOWNERS/PR template) (see `.github/AGENTS.md`) |
| `.githooks/` | `pre-commit` (SwiftFormat --lint + SwiftLint). Install with `make install-hooks` |

## For AI Agents

### Working In This Directory
- **Never work around permissions or security.** Request AX through the official API and let the user grant it in System Settings. Apple's own `tccutil reset` is fine.
- **Test permissions with `make run`** (Apple Development signing). `make build` passes `CODE_SIGNING_ALLOWED=NO` (ad-hoc), so its cdhash changes every build and TCC drops the grant — that target is for compile/CI checks only.
- `.docs/` is internal documentation: **never commit or push it** (it is gitignored).
- New sources placed under `Azimuth/` are **included automatically** by the file-system synchronized group (no pbxproj edit). Adding a new target or dependency still needs the pbxproj / Xcode GUI.

### Testing Requirements
- After any change: `make build` → `make lint` → `make test`. All must pass before merging (CI runs the same).
- For pure-logic changes, `make test` (direct swiftc compile, prints `PASS — all N checks`) is the fast regression check.
- When changing launch / Info.plist / target settings, do not stop at "the process is alive" — confirm **a window actually appears** (removing the storyboard once severed the delegate connection).

### Common Patterns
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` means every type is `@MainActor` by default. Mark pure, thread-agnostic logic explicitly `nonisolated`.
- Window geometry is handled internally in **AX coordinates** (top-left origin, Y down); flip between Cocoa and AX via `Shared/CoordinateSpace` when converting screen work areas.
- SwiftLint strict: no force-unwrap / force-cast (the exception is the narrow CF cast in `WindowAccess/AXAttribute` with a `swiftlint:disable` comment). Function/type body length and a 120-column line limit apply.

## Dependencies

### Internal
- Command execution data flow: hotkey/menu → `Commands/WindowCommandExecutor` → `WindowAccess` (app/window resolution and writes) + `Commands/CommandPlanPolicy` (decides the target frame and snap edge, delegating geometry to `FrameCalculator`) → `Commands/CommandOutcomePolicy` (decides what to commit from the actual AX result) → `WindowUndoStore` / `SnapStateStore`.

### External
- AppKit / Cocoa, ApplicationServices (AX), CoreGraphics, Carbon.HIToolbox (global hotkeys), ServiceManagement (launch at login).
- **Sparkle 2** (SPM, 2.9.3, revision `d46d456`): the auto-update framework. Initialized through `AppDelegate`'s `SPUStandardUpdaterController`, which is the target of every "Check for Updates…" item (App menu, status-bar menu, Settings Updates card).

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
