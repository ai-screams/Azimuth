# Main and legacy builds

Azimuth ships two builds from one repository. This page explains how they relate, and what to do when a
change on one side matters to the other. The same file exists on `main` and on `legacy/10.13`.

## The two channels

| | Main build | Legacy build |
| -- | -- | -- |
| Branch | `main` | `legacy/10.13` |
| macOS | 13 and later | 10.13 High Sierra through 12 Monterey |
| What goes in | New features and fixes | **Critical and security fixes only** (feature-frozen at 1.7.2) |
| Release tag | `vX.Y.Z` (pre-release `vX.Y.Z-rcN`) | `legacy-vX.Y.Z-N` (test build `legacy-rc-vX.Y.Z-N`) |
| Workflow | `release.yml` | `release-legacy.yml` |
| Build number | Commit count (210 and up) | `209.N`, shown as "Legacy N" |
| Update feed | Latest release's `appcast.xml` | The `legacy-feed` release's `appcast.xml` |
| Toolchain | Current Xcode | Xcode 26.3, pinned in CI (newer Xcode rejects targets below macOS 12) |

The branches split at 1.7.2 and **do not share code automatically**. A change merged to `main` never reaches
legacy users unless someone ports it.

A legacy user who upgrades to macOS 13 or later is moved to the main build on their next update check. The legacy
build numbers stay below main's for that reason.

## Does a main change need to go to legacy?

Port it when **all** of these hold:

1. It fixes a crash, data loss, a window landing in the wrong place, a permission problem, or a security issue.
2. The same bug exists on the legacy branch (check the code there, since it may differ).
3. Users on macOS 10.13 to 12 can hit it.

Do **not** port new features, new commands or settings, UI polish, performance work, or docs about main-only
behavior. The legacy build stays feature-frozen so that it keeps working on old Macs with the least risk.

Every PR answers this question in the **Legacy build** section of the PR template.

## How to port a fix

1. Fix it on `main` and open that PR as usual.
2. Branch off `legacy/10.13` and apply the same fix. `git cherry-pick` often conflicts: legacy code routes macOS
   gaps through `Shared/LegacySupport.swift` and cannot call APIs newer than 10.13 without a guard. Adapt the fix
   rather than forcing the pick.
3. Check it there. Xcode 27 rejects the legacy deployment target, so locally run `make legacy-check`; CI builds it
   with Xcode 26.3. Use `make legacy-app` for a signed test app to run on real hardware.
4. Open the PR against `legacy/10.13`. Title it like the main PR with a ` (legacy)` suffix and link the main PR.
5. Merge the main PR first, then the legacy PR. The exception is a fix that touches a file listed in
   `scripts/shared-with-legacy.txt`: merge the legacy PR first, then re-run the main PR's checks and merge it
   (see below).
6. Release it as described in that branch's `RELEASING.md`:
   1. tag a test build `legacy-rc-vX.Y.Z-N` and check it on a real Mac;
   2. tag the **same commit** `legacy-vX.Y.Z-N`;
   3. update the legacy download links on `main`: `docs/index.html`, `docs/manual.html`, README, and SECURITY
      (see `RELEASING.md` on `main`).

`N` is one serial for the whole legacy channel. Test builds use numbers too, so public releases can skip some
(1, 3, …).

## Files kept identical on both branches

Some files have no reason to differ, so they are kept byte-for-byte the same on both branches. They are listed
in [`scripts/shared-with-legacy.txt`](scripts/shared-with-legacy.txt).

- On `main`, the CI job `release-scripts` compares every listed file with `legacy/10.13` and fails if one is
  missing or different.
- When you change a listed file, open the matching PR on `legacy/10.13`. Merge the legacy PR first, then the
  main PR, or main's CI stays red.
- If a listed file must start to differ, remove it from the list on both branches in the same pair of PRs.
  For example, if main moves to a Sparkle release that legacy cannot use, the Sparkle adapter files may have to
  leave the list.
- The legacy release job also compares the release-notes script with `main` right before it publishes.

A file that was ported with changes (for example `Permissions/AccessibilityRequestPolicy.swift`, whose comments
name "System Preferences" on legacy) is **not** on the list. Port it by hand.

## What does not happen automatically on legacy

- **Dependabot** only watches `main`. The legacy branch keeps its GitHub Actions pins until someone updates them.
  Update them there when a security advisory affects an action it uses, or when a pinned action stops working.
- **Scheduled CodeQL** runs only from the default branch. Legacy CodeQL runs on pushes to `legacy/10.13`.
- **Sparkle** on legacy is pinned to an exact 2.9.x release (asserted by `scripts/legacy-sparkle-pin.sh`),
  because 2.10 and later require macOS 12. The 2.9 series still gets security fixes, so a new 2.9.x with a
  security fix **is** a legacy port: update the exact version and revision in the project, `Package.resolved`
  and that script. Do not move legacy to 2.10 or later.

## When main drops macOS 13

The main build supports macOS 13 and later. If it ever needs 14 or later, keep a last 13-compatible item in the
main feed. Open a `legacy/13` branch only if 13 users actually need fixes. Its build numbers must sort between
`209.N` and main's. Do not create that branch in advance.
