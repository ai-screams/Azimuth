# Security Policy

Azimuth is a macOS window manager that uses the **Accessibility (AX) API** to move and
resize other apps' windows. It collects no data, has no telemetry, and makes no network
connections other than its update check. We take the integrity of the app — and the trust
implied by the Accessibility permission — seriously.

## Supported versions

Azimuth auto-updates in place (via Sparkle) on two channels: the **regular** release for macOS 14 and later,
and a feature-frozen **legacy** build for macOS 10.13–12 (branch `legacy/10.13`). Only the latest build of
each channel receives fixes; older builds are expected to update in place. macOS 13 stays on 1.7.7, the last
regular release that runs there, and no longer receives fixes.

| Version | Supported |
|---------|-----------|
| Latest release (`v2.x`, macOS 14+) | ✅ |
| Latest legacy build ([`legacy-v1.7.2-4`](https://github.com/ai-screams/Azimuth/releases/tag/legacy-v1.7.2-4), macOS 10.13–12) | ✅ security fixes and other critical bug fixes only |
| [`v1.7.7`](https://github.com/ai-screams/Azimuth/releases/tag/v1.7.7) (macOS 13) | ❌ end of support (upgrade macOS to 14 or later to keep receiving fixes) |
| Older releases | ❌ (update to the latest) |

The legacy build depends on an older update framework (Sparkle 2.9.x, the last line that runs on macOS 10.13).
If that can no longer be shipped safely, the legacy build will be retired with notice in its release notes and here;
after upgrading macOS, a legacy install moves to the regular feed on its next update check (1.7.7 on macOS 13,
the latest on 14 or later).

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Report privately through GitHub's **Private vulnerability reporting**:

1. Go to the [Security tab](https://github.com/ai-screams/Azimuth/security) of this repository.
2. Click **Report a vulnerability** and fill in the advisory form.

If private reporting is unavailable, contact the maintainer
[@pignuante](https://github.com/pignuante) and ask for a private channel **before** sharing any
details — do not post specifics publicly.

Please include, where possible:

- The affected version (see **Azimuth → About** or the release tag).
- macOS version and hardware.
- A clear description and, ideally, reproduction steps or a proof of concept.
- The impact you believe it has.

## What to expect

- **Acknowledgement** as soon as we can, typically within a few days.
- An assessment and, for confirmed issues, a fix in the next release with a corresponding
  advisory. We're happy to credit reporters who want it.

## Scope

Especially relevant for Azimuth:

- **Update integrity** — releases are Developer ID–signed, Apple-notarized, and each Sparkle
  update is verified against an **EdDSA** signature. Reports that could bypass any of these are
  in scope.
- **Accessibility usage** — Azimuth requests AX permission through the official API and uses it to
  move/resize windows and to read the focused window's frame (for the command palette's preview outline).
  Any behavior that reads or exfiltrates data beyond that, or that could be abused via Azimuth's AX access,
  is in scope.
- **Keyboard observation** — while the shortcut cheat sheet is on (Settings → General → Cheat Sheet, on by default),
  Azimuth watches global modifier-key changes and key-down events with `NSEvent` monitors. It uses only which
  modifiers are held and the fact that some key was pressed (to close the sheet); it does not read which key
  or character, and records nothing. Turning the cheat sheet off removes the monitors.
- **Global shortcuts** — window commands and the command palette (`⌃⌥P` by default) are registered as
  Carbon hotkeys, which deliver only their own key combinations.
- **Installer cleanup** — on the first launch of a build from Applications, if an Azimuth disk image the user
  attached is still mounted, Azimuth asks before running `diskutil eject` on it and moving the `.dmg` file to the
  Trash. It never deletes, and touching the Downloads folder goes through the macOS permission prompt.
- **Supply chain** — the release pipeline, signing keys handling, and dependency integrity
  (e.g. Sparkle pinned via SPM).

Out of scope: issues that require a already-compromised machine or admin/root, social
engineering of the user into disabling macOS protections, or vulnerabilities solely in
third-party software Azimuth does not bundle.

## Our commitments

We follow the project's core rule: **security is solved the legitimate way, never by
bypassing macOS protections** (no SIP disabling, no TCC database tampering, no undocumented
permission workarounds). Fixes address root causes through the OS-sanctioned APIs.
