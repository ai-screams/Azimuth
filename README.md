# Azimuth

<!-- Release & install -->
[![Download](https://img.shields.io/badge/Download-.dmg-1a2a4a?logo=apple&logoColor=white)](https://github.com/ai-screams/Azimuth/releases/latest)
[![Latest release](https://img.shields.io/github/v/release/ai-screams/Azimuth?sort=semver&color=1a2a4a)](https://github.com/ai-screams/Azimuth/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-screams/Azimuth/total?color=1a2a4a&label=downloads)](https://github.com/ai-screams/Azimuth/releases)
[![Homebrew](https://img.shields.io/badge/Homebrew-ai--screams%2Ftap-F9AB00?logo=homebrew&logoColor=white)](#homebrew)

<!-- Built with -->
[![Platform](https://img.shields.io/badge/macOS-14%2B-555555?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)](https://swift.org)
[![AppKit](https://img.shields.io/badge/AppKit-1a2a4a?logo=apple&logoColor=white)](https://developer.apple.com/documentation/appkit)
[![Auto-update](https://img.shields.io/badge/Auto--update-Sparkle-8A4FFF)](https://sparkle-project.org)
[![Notarized](https://img.shields.io/badge/Notarized-Apple-000000?logo=apple&logoColor=white)](#install)

<!-- Project & support -->
[![CI](https://github.com/ai-screams/Azimuth/actions/workflows/ci.yml/badge.svg)](https://github.com/ai-screams/Azimuth/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/ai-screams/Azimuth?color=1a2a4a)](LICENSE)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](https://github.com/ai-screams/Azimuth/pulls)
[![Stars](https://img.shields.io/github/stars/ai-screams/Azimuth?style=flat&color=1a2a4a)](https://github.com/ai-screams/Azimuth/stargazers)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-support-FF5E5B?logo=kofi&logoColor=white)](https://ko-fi.com/pignuante)

Azimuth is a keyboard-driven window manager for macOS, built with Swift and AppKit. It lives in the menu bar and lets you place, resize, move, and throw the focused window across your screens with predictable shortcuts — no mouse, no guesswork.

Design principle: **predictability over clever inference.** Every command does exactly one well-defined thing, and effects compose. If you can get a result by combining simple commands, Azimuth doesn't add a separate "smart" feature for it.

## Highlights

- **Halves & snap-throw** — snap the window to a screen half; press again toward the same edge to throw it to the adjacent display.
- **Thirds & two-thirds** — left/center/right and top/middle/bottom, horizontally or vertically.
- **Maximize / center** — fill the work area or center at the current size.
- **Maximize with gaps** — fill the work area but leave a uniform inset on all sides (`⌃⌥⇧↩`).
- **Move (keep size)** — nudge the window one step in any direction, clamped to the work area.
- **Relative shrink** — shrink the window to **1/2** or **2/3** of its *current* size against a pinned edge (not the screen). Effects compose: 2/3 then 1/2 lands on 1/3.
- **Move to next display** — send the window to an adjacent monitor, preserving its shape and relative position.
- **Undo** — restore the previous frame, one step per window.
- **Multi-monitor aware** — position-aware adjacent-display selection (the window goes to the monitor that lines up with where it currently is).
- **Two presets** — Standard (arrow keys) and Vim (HJKL), each fully customizable with conflict warnings.
- **Automatic updates** — Azimuth checks for new releases and updates in place (via Sparkle), or check on demand from the menu. Updates are Apple-notarized **and** EdDSA-signature verified.

## Requirements

- macOS 14 (Sonoma) or later.
- **Accessibility permission** (Azimuth controls other apps' windows through the Accessibility API).

## Privacy

Azimuth runs entirely on your Mac. It collects no data, has no telemetry or analytics, and makes no network connections other than checking for updates (Sparkle). The Accessibility permission is used solely to move and resize the windows of the app you're using.

## Install

### Download (recommended)

1. Download the latest `Azimuth-<version>.dmg` from the [Releases page](https://github.com/ai-screams/Azimuth/releases/latest).
2. Open the DMG and drag **Azimuth** into your **Applications** folder.
3. Launch it, then enable **Azimuth** in **System Settings → Privacy & Security → Accessibility**.

The build is Developer ID–signed and notarized, so it opens without Gatekeeper warnings.

### Homebrew

```bash
brew install --cask ai-screams/tap/azimuth
```

Then enable **Azimuth** in **System Settings → Privacy & Security → Accessibility**. Updates are handled in-app (Sparkle), so `brew upgrade` won't fight the built-in updater.

### Build from source

```bash
git clone https://github.com/ai-screams/Azimuth
cd Azimuth
make run
```

`make run` builds and launches a properly **code-signed** build (Apple Development identity), which keeps your Accessibility grant stable across rebuilds. `make build` is ad-hoc signed (compile/CI checks only) and not for daily use.

### Grant Accessibility permission

On first launch, open **System Settings → Privacy & Security → Accessibility** and enable **Azimuth**. The menu bar item and the Settings window both show the current permission state and a shortcut to the right settings pane.

## Uninstall

Azimuth has no installer, so removing it is just a few steps:

1. Quit Azimuth, then drag it from **Applications** to the Trash.
2. Remove its Accessibility entry: **System Settings → Privacy & Security → Accessibility** → select **Azimuth** → click **−**. macOS keeps this entry even after an app is deleted, and no app can remove its own entry through the system — so this step is manual (the same is true for every app that uses Accessibility).
3. *(Optional)* delete its preferences: `defaults delete com.aiscream.Azimuth`

If you enabled **Launch at login**, that registration is cleared automatically once the app is removed.

## Shortcuts

Azimuth separates command groups by modifier layer:

| Layer | Purpose |
|-------|---------|
| `⌃⌥` (Control+Option) | Halves (snap/throw) · Maximize · Center · Undo · Thirds & two-thirds (number keys) |
| `⌃⌥⌘` | **Move** (keep current size) |
| `⌃⌥⇧` | **Relative shrink** — ½ on arrows, ⅔ on `M , . /` |
| `⌃⌥⌘⇧` | **Move to next display** |

### Standard preset (default)

| Group | Command | Shortcut |
|-------|---------|----------|
| Halves (snap + throw) | Left / Right | `⌃⌥←` / `⌃⌥→` |
| | Top / Bottom | `⌃⌥↑` / `⌃⌥↓` |
| Maximize · Undo · Center | Maximize | `⌃⌥↩` (Return) |
| Maximize · Undo · Center | Maximize with gaps | `⌃⌥⇧↩` (Return) |
| | Undo | `⌃⌥⌫` (Delete) |
| | Center | `⌃⌥C` |
| Thirds (1/3) | Horizontal left·center·right | `⌃⌥1` / `⌃⌥2` / `⌃⌥3` |
| | Vertical top·middle·bottom | `⌃⌥4` / `⌃⌥5` / `⌃⌥6` |
| Two-thirds (2/3) | Horizontal left·right | `⌃⌥7` / `⌃⌥8` |
| | Vertical top·bottom | `⌃⌥9` / `⌃⌥0` |
| Move (keep size) | Left·Right·Up·Down | `⌃⌥⌘←` / `→` / `↑` / `↓` |
| Relative shrink (½) | Left·Right·Up·Down | `⌃⌥⇧←` / `→` / `↑` / `↓` |
| Relative shrink (⅔) | Left·Down·Up·Right | `⌃⌥⇧ M , . /` |
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
- **Maximize with gaps** — like Maximize, but leaves a uniform 12pt inset on all four sides so the window doesn't touch the screen edges. Falls back to a plain maximize if the work area is too small for the gap.
- **Thirds / two-thirds** — axis-independent: horizontal commands change only x/width, vertical only y/height, so they compose (e.g. horizontal-third then vertical-third → a corner cell).
- **Halves + throw** — if the window isn't already in that half, it snaps there. If it *is*, Azimuth throws it to the adjacent display in that direction and places it in the opposite half (throwing right lands it in the target's left half). No adjacent display → it stays put.
- **Move** — keeps the current size and nudges the window by its own width/height, clamping at the work-area edge. It never resizes or changes display; repeated presses push it to the edge.
- **Center** — keeps size, centers in the work area.
- **Relative shrink (½ / ⅔)** — based on the *current window*, not the screen: pins the chosen edge and shrinks toward it. Arrow keys shrink to ½; `M , . /` shrink to ⅔ (M=left, ,=down, .=up, /=right). Effects compose: ⅔ then ½ lands on ⅓.
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
- Automatic updates via Sparkle — current version + Check for Updates… in Settings (and the menu bar / App menu).

If the menu bar icon is hidden, relaunching Azimuth reopens the Settings window so you always have a way back in.

## Roadmap

| Version | Theme |
|---------|-------|
| v1 | Stabilization across representative apps — shipped / stable |
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

## Support

Azimuth is free and open source — no paywall, no ads, no telemetry — and it always will be. If it earns a place in your workflow, you can chip in to fund its development:

<p>
  <a href="https://ko-fi.com/pignuante">
    <img src="https://img.shields.io/badge/Support%20on-Ko--fi-FF5E5B?style=for-the-badge&logo=kofi&logoColor=white" alt="Support on Ko-fi" height="40">
  </a>
  &nbsp;
  <a href="https://github.com/sponsors/ai-screams">
    <img src="https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white" alt="Sponsor on GitHub" height="40">
  </a>
</p>

- 💛 **Ko-fi** — a one-time tip or a **supporter license** · ♥ **GitHub Sponsors** — recurring support

A supporter license is simply a way to say thanks — it unlocks nothing, because every feature is already free for everyone. Entirely optional, always appreciated: there is no paywall and never will be.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

Copyright 2026 AiScream. "Azimuth" and the project name/branding are not granted under the license (Apache-2.0 does not grant trademark rights).
