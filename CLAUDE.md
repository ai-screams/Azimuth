# CLAUDE.md

Orientation for Claude Code (and other AI agents) working in **Azimuth**. This is the top-level
summary; the per-directory **`AGENTS.md` files are the detailed source of truth** — read the
`AGENTS.md` in a directory before changing files there.

## What this is

Azimuth is a menu-bar **window manager for macOS** (Swift + AppKit, programmatic entry at
`Azimuth/main.swift`, no storyboard). It uses the Accessibility (AX) API to move/resize other
apps' focused windows via global hotkeys (Carbon) and menu commands. It auto-updates via
Sparkle 2 and ships Developer ID–signed, Apple-notarized, and EdDSA-verified.

## Build / test / lint

| Command | Use |
|---------|-----|
| `make run` | Build a **signed** app and launch it — use for anything needing Accessibility |
| `make build` | Compile-only (ad-hoc signed; CI/compile checks) — **not** for permission testing |
| `make test` | Pure-logic command-engine tests (swiftc, AppKit-free); prints `PASS — all N checks` |
| `make lint` / `make format` | SwiftLint (strict) / SwiftFormat |
| `make secrets` | gitleaks secret scan |
| `make install-hooks` | pre-commit hook: SwiftFormat `--lint` + SwiftLint `--strict` |

Before opening a PR: `make build && make lint && make test` (CI runs the same, plus gitleaks).

## Non-negotiable rules

- **Never bypass macOS permissions or security.** Request AX through the official API; the user
  grants it in System Settings. No SIP disabling, no TCC tampering, no undocumented workarounds.
  Apple's own `tccutil reset` is fine. Fix root causes the OS-sanctioned way.
- **Test anything permission-related with `make run`** (stable Apple Development signing).
  `make build` is ad-hoc → its cdhash changes every build → TCC resets the grant. Ad-hoc builds
  are for compile/CI only.
- **`.docs/` is internal — never commit or push it** (it is gitignored).
- **GUI smoke tests:** do not read other apps' `kCGWindowName` (Screen Recording TCC gate that
  has frozen WindowServer). Confirm liveness via process + AX role checks. Never busy-loop to
  wait — poll a condition.

## Code conventions

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: every type is `@MainActor` by default. Keep pure,
  thread-agnostic logic explicitly `nonisolated` in the AppKit-free layer so `make test` can
  exercise it (this is why geometry/command logic lives in `Commands/` and `Shared/`).
- Window geometry is handled in **AX coordinates** (top-left origin, Y down); convert to/from
  Cocoa work areas via `Shared/CoordinateSpace`.
- SwiftLint strict: no force-unwrap / force-cast (narrow, commented exceptions only), 120-column
  lines, function/type body-length limits. Match surrounding comment density and idiom.
- **Conventional Commits** (`feat(scope): …`, `fix: …`, `docs: …`, `refactor: …`, `chore: …`).
  Branch off `main`, keep PRs focused, **squash-merge**.

## Docs (`docs/` is the GitHub Pages source)

- `index.html` (landing) and `manual.html` (user manual) are **bilingual**: each string exists as
  a `data-en` attribute, a `data-ko` attribute, **and** the visible inner text (a JS toggle swaps
  it). Any copy change must update **all three**, or the languages drift.
- Strings like "N commands" / "N shortcuts" must match `WindowCommand.menuCommands`
  (currently **34**). Bumping a command means updating both HTML files and the README.
- Merging to `main` triggers the **"pages build and deployment"** workflow. The live site
  (`ai-screams.github.io/Azimuth`) lags until that run finishes — poll it to `completed`/`success`
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
