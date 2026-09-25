# CLAUDE.md

Orientation for Claude Code (and other AI agents) working in **Azimuth**. This is the top-level
summary; the per-directory **`AGENTS.md` files are the detailed source of truth** — read the
`AGENTS.md` in a directory before changing files there.

## What this is

Azimuth is a menu-bar **window manager for macOS** (Swift + AppKit, programmatic entry at
`Azimuth/main.swift`, no storyboard). It uses the Accessibility (AX) API to move/resize other
apps' focused windows via global hotkeys (Carbon) and menu commands. It auto-updates via
Sparkle 2 and ships Developer ID–signed, Apple-notarized, and EdDSA-verified.

## Layout

| Path | What |
|------|------|
| `Azimuth/` | App source (per-dir `AGENTS.md`); flow: hotkey/menu → `Commands/WindowCommandExecutor` → `WindowAccess` + `Commands/FrameCalculator` + `WindowAccess/WindowUndoStore` |
| `Tests/` | Pure-logic command-engine regression tests (single-file swiftc harness) |
| `scripts/` | `build`/`run`/`lint`/`format`/`test`/`coverage`/`secrets` shell scripts |
| `docs/` | GitHub Pages source (landing + manual) |
| `.github/` | CI workflows, `FUNDING.yml`, PR template, `CODEOWNERS` |

## Build / test / lint

| Command | Use |
|---------|-----|
| `make run` | Build a **signed** app and launch it — use for anything needing Accessibility |
| `make build` | Compile-only (ad-hoc signed; CI/compile checks) — **not** for permission testing |
| `make test` | Pure-logic tests (swiftc). Sources listed in `scripts/harness-sources.sh` — **one place**, shared with `make coverage`. Not "AppKit-free": the bar is whether a type can be built as a *value* (an `AXUIElement`-carrying one cannot), so `Hotkeys/CarbonModifier.swift` is in despite `import AppKit`. Prints `PASS — all N checks` |
| `make coverage` | LLVM line coverage on the pure-logic layer; gate **≥90%** (`COVERAGE_MIN`). The denominator is `harness-sources.sh` only — ~2,000 of ~6,500 lines, so a 99% figure says nothing about `WindowAccess/**` or the UI |
| `make lint` / `make format` | SwiftLint (strict) / SwiftFormat |
| `make secrets` | gitleaks secret scan |
| `make install-hooks` | pre-commit hook: SwiftFormat `--lint` + SwiftLint `--strict` |

Before opening a PR: `make build && make lint && make test` (CI runs the same, plus gitleaks).

- After `make run`, `make build` can fail with a **Sparkle.framework "permission to save"** error —
  signed and ad-hoc builds share one DerivedData. Quit the app, `rm -rf` the built `Azimuth.app`, rebuild.
- `make run` can fail at the **link step** two ways, both fixed the same way (quit, `command rm -rf` the
  built `Azimuth.app`, rebuild): (a) the app is already running — `scripts/run.sh` pkills *after* the
  build, so it does not save you; (b) `Assets.car … permission to access "Resources"`
  (NSCocoaErrorDomain 513) from a stale bundle, with nothing running. `pkill -x Azimuth` also quits
  the `/Applications` release copy.
- **Never `make build` while a `make run` app is running** — same shared DerivedData: it swaps the
  bundle under the live process, invalidating its signature, and macOS silently drops the app's
  Accessibility grant. Every command then dies while System Settings still shows it enabled.
  `codesign -dvvv` on the built app showing `flags=…adhoc…` confirms it; quit, `rm -rf`, `make run`.
- To compile-check **while** a signed app runs, build into a throwaway DerivedData so the live
  bundle is untouched: `xcodebuild -project Azimuth.xcodeproj -scheme Azimuth -configuration Debug
  -destination platform=macOS -derivedDataPath /tmp/az-check CODE_SIGNING_ALLOWED=NO build`.
  `#if DEBUG` differs by configuration, so verify both `-configuration Debug` **and** `Release`
  when a change touches a `#if DEBUG` block.
- `main` is branch-protected: `lint-and-build` / `gitleaks` / `secret-scan` must go green before
  `gh pr merge --squash` (it reports `BLOCKED` until then).
- Squash-merge **deletes the head branch**, so a PR stacked on it auto-closes on merge and GitHub
  won't let you reopen or re-target it — recreate it against `main`. And when one PR moves code
  another edits (e.g. splitting a test file that a second PR patches), merge the **content change
  first, the move last**, or the mechanical PR conflicts.
- A **single-commit** PR squash-merges under that commit's subject, not the PR title. Pass
  `gh pr merge --squash --subject "<English PR title>"` to keep `git log` titles English.
- Two branches cut from the same `main` almost always conflict in a per-directory `AGENTS.md` —
  each adds a row to the same table, and both bump the `Updated:` header. Keep **both** rows;
  whichever PR merges second rebases.
- Xcode, while open, rewrites `Azimuth.xcodeproj/project.pbxproj` on its own (key order, quoting).
  `git checkout --` it before committing so that noise does not ride along.

## Non-negotiable rules

- **Never bypass macOS permissions or security.** Request AX through the official API; the user
  grants it in System Settings. No SIP disabling, no TCC tampering, no undocumented workarounds.
  Apple's own `tccutil reset` is fine. Fix root causes the OS-sanctioned way.
- **Test anything permission-related with `make run`** (stable Apple Development signing).
  `make build` is ad-hoc → its cdhash changes every build → TCC resets the grant. Ad-hoc builds
  are for compile/CI only. Debug builds use bundle id `com.aiscream.Azimuth.debug` — a separate
  TCC identity and defaults domain from the installed release copy (prevents grant clashes).
- **Verify `HotkeyService` changes with an actual hotkey** — the status-bar menu path never goes
  through it, so a passing menu command proves nothing. That split is also the fastest triage:
  menu works but hotkeys dead → hotkey registration; both dead → Accessibility/TCC.
- **`.docs/` is internal — never commit or push it** (it is gitignored).
- **GUI smoke tests:** do not read other apps' `kCGWindowName` (Screen Recording TCC gate that
  has frozen WindowServer). Confirm liveness via process checks — a scratch/ad-hoc binary
  **cannot** query another app's AX (the *querying* process needs its own grant; you get `-25211`
  apiDisabled), so actual window behavior must be exercised by a human. Never busy-loop to wait —
  poll a condition.

## Code conventions

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: every type is `@MainActor` by default. Keep pure,
  thread-agnostic logic explicitly `nonisolated` in the AppKit-free layer so `make test` can
  exercise it (this is why geometry/command logic lives in `Commands/` and `Shared/`).
- Window geometry is handled in **AX coordinates** (top-left origin, Y down); convert to/from
  Cocoa work areas via `Shared/CoordinateSpace`.
- SwiftLint strict: no force-unwrap / force-cast (narrow, commented exceptions only), 120-column
  lines, function/type body-length limits. Match surrounding comment density and idiom.
- Keep multi-line `if` conditions on **one line** (≤120 cols; extract a local `Bool` if needed):
  SwiftFormat moves a wrapped condition's `{` to its own line, SwiftLint's `opening_brace` then
  rejects it, and the pre-commit hook deadlocks. (Multi-line `guard … else {` is fine.)
- `--strict` promotes SwiftLint *default* rules to errors — notably **max 5 function params**,
  **max 2-member tuples**, and **cyclomatic complexity ≤ 10** (adding a `switch` to an already
  branchy function trips it — extract a helper); bundle into a struct or recompute locally instead.
- **Conventional Commits** (`feat(scope): …`, `fix: …`, `docs: …`, `refactor: …`, `chore: …`).
  Branch off `main`, keep PRs focused, **squash-merge**.
- New source files under `Azimuth/` are auto-included via the Xcode **file-system synchronized
  group** — no `.pbxproj` edit needed. Adding a new target or SPM dependency still needs the
  pbxproj / Xcode GUI. Deployment target: macOS **13.0**.
- A macOS 14+ API is a compile error at that target — guard it with `if #available` and decide the
  13 fallback. Bring the app forward only through `NSApp.bringToFront()` (`Shared/`), never
  `NSApp.activate…` directly. String-keyed resources (SF Symbol names, `x-apple.systempreferences:`
  URLs) are not availability-checked — confirm they exist on macOS 13.
- That auto-include does **not** reach the test harness: a new pure-logic file must be added to
  `scripts/harness-sources.sh` (the single list both `make test` and `make coverage` read).
- Those lists are the **only** automatically tested code — `WindowAccess/**`, `WindowCommandExecutor`,
  and `HotkeyService` are type-checked by `make build` and nothing more. A broken reference in those
  files still passes `make test` — run `xcodebuild` after touching them. To cover an AX failure mode,
  extract the decision into a pure function (values in → decision out) and test that; a protocol seam
  carrying `AXUIElement` cannot compile in the swiftc harness. `Commands/*Policy.swift` is that family:
  outcome, plan, feedback, write-retry, shortcut-list, shortcut-row.

## Docs (`docs/` is the GitHub Pages source)

- `index.html` (landing) and `manual.html` (user manual) are **bilingual**: each string exists as
  a `data-en` attribute, a `data-ko` attribute, **and** the visible inner text (a JS toggle swaps
  it). Any copy change must update **all three**, or the languages drift.
- Strings like "N commands" / "N shortcuts" must match `WindowCommand.menuCommands`
  (currently **34**). Bumping a command means updating both HTML files and the README.
- Merging to `main` triggers the **"pages build and deployment"** workflow. The live site
  (`ai-scream.ai/Azimuth`) lags until that run finishes — poll it to `completed`/`success`
  before verifying live content; catching the old page mid-deploy is expected.

## Funding / community

- GitHub Sponsors → the org **`ai-screams`** (`github.com/sponsors/ai-screams`); Ko-fi →
  **`pignuante`** (`ko-fi.com/pignuante`). These are independent handles; see `.github/FUNDING.yml`.
  The repo ♡ Sponsor button also requires **Settings → General → Features → Sponsorships** enabled,
  not just `FUNDING.yml`.
- Community health files live at the repo root: `SECURITY.md`, `CONTRIBUTING.md`, `SUPPORT.md`,
  `CODE_OF_CONDUCT.md`.

## Environment gotchas

- The shell is **zsh**: `status` is a read-only variable — do not use it as a variable name in
  Bash-tool scripts (use `st`, etc.).
- Ko-fi and GitHub pages return **HTTP 403 to `curl`** (bot protection) — that is not a real
  failure signal. Verify shields.io badge URLs return **200** before committing new badges.
