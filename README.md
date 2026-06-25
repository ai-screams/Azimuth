# Azimuth

[![Download](https://img.shields.io/badge/Download-.dmg-1a2a4a?logo=apple&logoColor=white)](https://github.com/ai-screams/Azimuth/releases/latest)
[![Latest release](https://img.shields.io/github/v/release/ai-screams/Azimuth?sort=semver&color=1a2a4a)](https://github.com/ai-screams/Azimuth/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-26.3%2B-555555)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)](https://swift.org)
[![CI](https://github.com/ai-screams/Azimuth/actions/workflows/ci.yml/badge.svg)](https://github.com/ai-screams/Azimuth/actions/workflows/ci.yml)
[![Downloads](https://img.shields.io/github/downloads/ai-screams/Azimuth/total?color=1a2a4a)](https://github.com/ai-screams/Azimuth/releases)
[![License](https://img.shields.io/badge/license-TBD-lightgrey)](#)

Azimuth is a keyboard-driven window manager for macOS, built with Swift and AppKit. It lives in the menu bar and lets you place, resize, move, and throw the focused window across your screens with predictable shortcuts — no mouse, no guesswork.

Design principle: **predictability over clever inference.** Every command does exactly one well-defined thing, and effects compose. If you can get a result by combining simple commands, Azimuth doesn't add a separate "smart" feature for it.

## Highlights

- **Halves & snap-throw** — snap the window to a screen half; press again toward the same edge to throw it to the adjacent display.
- **Thirds & two-thirds** — left/center/right and top/middle/bottom, horizontally or vertically.
- **Maximize / center** — fill the work area or center at the current size.
- **Move (keep size)** — nudge the window one step in any direction, clamped to the work area.
- **Relative shrink** — halve the window against a pinned edge, based on its *current* size (not the screen).
- **Move to next display** — send the window to an adjacent monitor, preserving its shape and relative position.
- **Undo** — restore the previous frame, one step per window.
- **Multi-monitor aware** — position-aware adjacent-display selection (the window goes to the monitor that lines up with where it currently is).
- **Two presets** — Standard (arrow keys) and Vim (HJKL), each fully customizable with conflict warnings.

## Requirements

- macOS 26.3 (Tahoe) or later.
- **Accessibility permission** (Azimuth controls other apps' windows through the Accessibility API).

## Privacy

Azimuth runs entirely on your Mac. It collects no data, has no telemetry or analytics, and makes no network connections. The Accessibility permission is used solely to move and resize the windows of the app you're using.

## Install

### Download (recommended)

1. Download the latest `Azimuth-<version>.dmg` from the [Releases page](https://github.com/ai-screams/Azimuth/releases/latest).
2. Open the DMG and drag **Azimuth** into your **Applications** folder.
3. Launch it, then enable **Azimuth** in **System Settings → Privacy & Security → Accessibility**.

The build is Developer ID–signed and notarized, so it opens without Gatekeeper warnings.

### Build from source

```bash
git clone https://github.com/ai-screams/Azimuth
cd Azimuth
make run
```

`make run` builds and launches a properly **code-signed** build (Apple Development identity), which keeps your Accessibility grant stable across rebuilds. `make build` is ad-hoc signed (compile/CI checks only) and not for daily use.

### Grant Accessibility permission

On first launch, open **System Settings → Privacy & Security → Accessibility** and enable **Azimuth**. The menu bar item and the Settings window both show the current permission state and a shortcut to the right settings pane.

## Shortcuts

Azimuth separates command groups by modifier layer:

| Layer | Purpose |
|-------|---------|
| `⌃⌥` (Control+Option) | Halves (snap/throw) · Maximize · Center · Undo · Thirds & two-thirds (number keys) |
| `⌃⌥⌘` | **Move** (keep current size) |
| `⌃⌥⇧` | **Relative shrink** (½ against a pinned edge) |
| `⌃⌥⌘⇧` | **Move to next display** |

### Standard preset (default)

| Group | Command | Shortcut |
|-------|---------|----------|
| Halves (snap + throw) | Left / Right | `⌃⌥←` / `⌃⌥→` |
| | Top / Bottom | `⌃⌥↑` / `⌃⌥↓` |
| Maximize · Undo · Center | Maximize | `⌃⌥↩` (Return) |
| | Undo | `⌃⌥⌫` (Delete) |
| | Center | `⌃⌥C` |
| Thirds (1/3) | Horizontal left·center·right | `⌃⌥1` / `⌃⌥2` / `⌃⌥3` |
| | Vertical top·middle·bottom | `⌃⌥4` / `⌃⌥5` / `⌃⌥6` |
| Two-thirds (2/3) | Horizontal left·right | `⌃⌥7` / `⌃⌥8` |
| | Vertical top·bottom | `⌃⌥9` / `⌃⌥0` |
| Move (keep size) | Left·Right·Up·Down | `⌃⌥⌘←` / `→` / `↑` / `↓` |
| Relative shrink (½) | Left·Right·Up·Down | `⌃⌥⇧←` / `→` / `↑` / `↓` |
| Move to next display | Left·Right·Up·Down | `⌃⌥⌘⇧←` / `→` / `↑` / `↓` |

### Vim preset

Only the directional commands and Undo change keys; everything else (Maximize, Center, numbers) matches Standard.

| Difference | Mapping |
|------------|---------|
| Direction | `H` = left, `L` = right, `K` = up, `J` = down |
| Undo | `U` |

Example: `⌃⌥H` (left half) · `⌃⌥⌘K` (move up) · `⌃⌥⇧J` (shrink to bottom half) · `⌃⌥⌘⇧L` (move to right display) · `⌃⌥U` (undo).

> If a combination is already claimed by the system or another app, Azimuth's registration is skipped and the Settings window marks it **"In use by system."** Every shortcut can be remapped in Settings.

## Command behavior

- **Maximize** — fills the work area (visible area minus menu bar and Dock).
- **Thirds / two-thirds** — axis-independent: horizontal commands change only x/width, vertical only y/height, so they compose (e.g. horizontal-third then vertical-third → a corner cell).
- **Halves + throw** — if the window isn't already in that half, it snaps there. If it *is*, Azimuth throws it to the adjacent display in that direction and places it in the opposite half (throwing right lands it in the target's left half). No adjacent display → it stays put.
- **Move** — keeps the current size and nudges the window by its own width/height, clamping at the work-area edge. It never resizes or changes display; repeated presses push it to the edge.
- **Center** — keeps size, centers in the work area.
- **Relative shrink (½)** — based on the *current window*, not the screen: pins the chosen edge and halves toward it.
- **Move to next display** — preserves shape, relative position, and size (capped/clamped so it never exceeds the target screen). No adjacent display → stays put.
- **Undo** — restores the previous frame (one step per window). Display reconfiguration discards undo history.
- **Failure feedback** — a beep on failure (toggleable in Settings) plus a log entry. Transient failures during Space switches or animations are skipped silently.

> Note: apps with size increments (e.g. Terminal) may leave a sub-row gap when snapped to a half/maximize, because they round down to their character grid. The work area excludes the menu bar and Dock, so a gap at those edges is expected.

## Settings

Open Settings from the menu bar item or with `⌘,`:

- Switch preset (Standard / Vim).
- Record custom shortcuts per command, with conflict warnings and per-command Reset.
- Enable/disable command groups, or unbind individual commands.
- Toggle failure beep, launch-at-login, and hide the menu bar icon.

If the menu bar icon is hidden, relaunching Azimuth reopens the Settings window so you always have a way back in.

## Roadmap

| Version | Theme |
|---------|-------|
| v1 | Stabilization across representative apps (current) |
| v1.5+ | Anchor placement: snap/size the window relative to another window (same display) |
| v2 | Workspaces: per-app default positions, named scene save/restore |
| v3 | Automation: URL scheme, Shortcuts action, per-app rules |

## Development

Azimuth uses:

- `SwiftLint` for linting
- `SwiftFormat` for formatting
- `.editorconfig` for basic editor consistency

Install the tools with Homebrew:

```bash
brew install swiftlint swiftformat gitleaks
```

Common `make` targets, run from the project root:

```bash
make run      # build a signed app and launch it (use this to actually run Azimuth)
make build    # compile-only verification (ad-hoc signed; CI/compile checks only)
make test     # run the pure-logic command-engine tests (swiftc)
make lint     # SwiftLint (strict)
make format   # SwiftFormat
make secrets  # gitleaks secret scan
```

Xcode also runs `SwiftLint` during builds when it is installed locally. If `SwiftLint` is missing, the build shows a warning instead of failing.

### Git hooks

Install the local Git hooks once:

```bash
make install-hooks
```

The `pre-commit` hook runs `SwiftFormat --lint` and `SwiftLint --strict`.

### CI

GitHub Actions runs the same lint checks and a macOS `xcodebuild` build on pushes to `main` and on pull requests. It also runs `gitleaks` secret scanning and uploads a SARIF report to GitHub code scanning.
