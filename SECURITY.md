# Security Policy

Azimuth is a macOS window manager that uses the **Accessibility (AX) API** to move and
resize other apps' windows. It collects no data, has no telemetry, and makes no network
connections other than its update check. We take the integrity of the app — and the trust
implied by the Accessibility permission — seriously.

## Supported versions

Azimuth ships as a single, auto-updating app (via Sparkle). Only the **latest release** receives
security fixes; older builds are expected to update in place.

| Version | Supported |
|---------|-----------|
| Latest release (`v1.x`) | ✅ |
| Older releases | ❌ (update to the latest) |

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
- **Accessibility usage** — Azimuth requests AX permission through the official API and only
  moves/resizes windows. Any behavior that reads or exfiltrates data beyond that, or that could
  be abused via Azimuth's AX access, is in scope.
- **Supply chain** — the release pipeline, signing keys handling, and dependency integrity
  (e.g. Sparkle pinned via SPM).

Out of scope: issues that require a already-compromised machine or admin/root, social
engineering of the user into disabling macOS protections, or vulnerabilities solely in
third-party software Azimuth does not bundle.

## Our commitments

We follow the project's core rule: **security is solved the legitimate way, never by
bypassing macOS protections** (no SIP disabling, no TCC database tampering, no undocumented
permission workarounds). Fixes address root causes through the OS-sanctioned APIs.
