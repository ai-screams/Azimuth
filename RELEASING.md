# Releasing Azimuth

Azimuth ships as a **Developer ID–signed, notarized DMG** (drag-to-Applications). This is the
orthodox path for a non–App Store macOS app that needs Accessibility access (no sandbox).

## One-time prerequisites

1. **Apple Developer Program** membership (paid). The "Apple Development" certificate used for
   `make run` is for local dev only and **cannot** be used to distribute.
2. A **Developer ID Application** certificate in your login keychain
   (Xcode → Settings → Accounts → Manage Certificates → +, or the Developer portal).
3. A notarization credential — either:
   - a keychain profile: `xcrun notarytool store-credentials AzimuthNotary --apple-id <id> --team-id <TEAMID> --password <app-specific-password>`, or
   - an **app-specific password** (appleid.apple.com → Sign-In & Security → App-Specific Passwords).

## Local release

```bash
DEVELOPMENT_TEAM=7K6MK3KP9K \
NOTARY_PROFILE=AzimuthNotary \
make release            # or: ./scripts/release.sh 1.0.0
```

Or with an Apple ID instead of a stored profile:

```bash
DEVELOPMENT_TEAM=7K6MK3KP9K \
APPLE_ID=you@example.com \
APPLE_APP_PASSWORD=abcd-efgh-ijkl-mnop \
./scripts/release.sh 1.0.0
```

Output: `dist/Azimuth-<version>.dmg` — signed, notarized, stapled. The version defaults to the
latest git tag (leading `v` stripped) when omitted.

## Automated release (GitHub Actions)

Pushing a tag builds and publishes automatically:

```bash
git tag v1.0.0
git push origin v1.0.0
```

`.github/workflows/release.yml` then builds → signs → notarizes → packages the DMG → verifies it →
generates a **signed Sparkle `appcast.xml`** (EdDSA) → creates a **GitHub Release** with the DMG,
its `.sha256`, and `appcast.xml` attached, plus auto-generated notes.

The in-app updater (Sparkle) reads the feed from
`https://github.com/ai-screams/Azimuth/releases/latest/download/appcast.xml` (a stable redirect to
the newest release's appcast), so each new tagged release automatically becomes the offered update.
See [Auto-update (Sparkle)](#auto-update-sparkle).

The release job runs in a protected **`release` environment** and all actions are pinned to commit
SHAs (Dependabot keeps them current). With a required reviewer on the environment, a pushed tag
**waits for human approval** before the signing/notarization secrets are exposed — so a stolen tag
push cannot publish a signed build on its own.

### Required secrets (set on the `release` environment)

Add these under **Settings → Environments → `release` → Environment secrets** (preferred over
repo-wide secrets, so only the approved release job can read them):

| Secret | What |
|--------|------|
| `DEVELOPER_ID_CERT_P12` | Developer ID Application cert + private key exported as `.p12`, base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `DEVELOPER_ID_CERT_PASSWORD` | password set when exporting the `.p12` |
| `APPLE_TEAM_ID` | Apple Developer Team ID (e.g. `7K6MK3KP9K`) |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_APP_PASSWORD` | app-specific password for that Apple ID |
| `SPARKLE_ED_PRIVATE_KEY` | Sparkle EdDSA private key (base64), exported from the maintainer's Keychain — see [Auto-update](#auto-update-sparkle) |

### Enabling the automated release (one-time)

1. **Settings → Environments → New environment** → name it `release`. Add yourself as a
   **Required reviewer** (and optionally restrict deployment branches/tags).
2. Add the secrets above to that environment (including `SPARKLE_ED_PRIVATE_KEY`).
3. (Recommended) **Settings → Tags** → add a protection rule for `v*` so only maintainers can push
   release tags.
4. Push a tag (`git tag vX.Y.Z && git push origin vX.Y.Z`) → approve the run when prompted.

> **Never tag a final release on the same commit as its pre-release.** `CFBundleVersion` is derived
> from the commit count (`git rev-list --count HEAD`), which Sparkle uses to decide "is this newer?".
> Two tags on the same commit (e.g. `v1.3.0-rc1` then `v1.3.0` with no commit in between) get the
> **same** build number, so an RC tester would never be offered the final build. Always let the final
> release ride at least one new commit (the version-bump commit already does this in the normal flow).

> Future hardening (optional): switch notarization to an **App Store Connect API key**
> (`notarytool --key/--key-id/--issuer`) to avoid exposing the Apple ID + app password; this needs a
> `(C)` branch in `scripts/release.sh`.

## Auto-update (Sparkle)

Azimuth embeds [Sparkle 2](https://sparkle-project.org) for in-app updates. The app checks an
**appcast** feed, and offers/installs newer signed builds. Updates are verified two ways: Apple
notarization (Gatekeeper) **and** Sparkle's own **EdDSA** signature (guards against a tampered feed).

- **Feed URL** (`SUFeedURL` in `Azimuth/Info.plist`):
  `https://github.com/ai-screams/Azimuth/releases/latest/download/appcast.xml` — a stable redirect
  to the appcast attached to the latest GitHub Release.
- **Public key** (`SUPublicEDKey` in `Info.plist`) is shipped in the app; the **private key** lives
  only in the maintainer's Keychain and as the `SPARKLE_ED_PRIVATE_KEY` CI secret.
- The release workflow runs `generate_appcast` (from the Sparkle tools) against the freshly
  signed/notarized DMG, signs it with the EdDSA key, and uploads `appcast.xml` as a release asset.

### One-time key setup (maintainer)

The EdDSA key only needs to be generated **once** (one key covers all versions):

```bash
# generate_keys ships with the Sparkle SPM package (…/artifacts/sparkle/Sparkle/bin/) or the
# Sparkle tools tarball. It stores the private key in your login Keychain and prints the public key.
generate_keys                       # prints SUPublicEDKey (already set in Info.plist)
generate_keys -x sparkle_key         # export the private key to a file (keep OUTSIDE the repo)
```

Then add the exported key as the `SPARKLE_ED_PRIVATE_KEY` environment secret (the file content is a
single base64 line). The current public key is already committed in `Azimuth/Info.plist`; only
**regenerate** if the private key is lost (which would require shipping a new public key in an app
update before the next Sparkle-verified update can work).

## Website download link

`docs/index.html` (the GitHub Pages landing page) links to the **latest** release and fills in the
version via the GitHub Releases API, so no manual edit is needed per release — once a tagged release
exists, the site's Download button points to its `.dmg` automatically.

## First-launch note for users

The app launches immediately after dragging to Applications, but window control only works after the
user enables Azimuth in **System Settings → Privacy & Security → Accessibility** (standard for this
class of app).
