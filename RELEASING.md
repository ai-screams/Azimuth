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

`.github/workflows/release.yml` then builds → signs → notarizes → packages the DMG → creates a
**GitHub Release** with the DMG attached and auto-generated notes.

### Required GitHub repository secrets

| Secret | What |
|--------|------|
| `DEVELOPER_ID_CERT_P12` | Developer ID Application cert + private key exported as `.p12`, base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `DEVELOPER_ID_CERT_PASSWORD` | password set when exporting the `.p12` |
| `APPLE_TEAM_ID` | Apple Developer Team ID (e.g. `7K6MK3KP9K`) |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_APP_PASSWORD` | app-specific password for that Apple ID |

## Website download link

`docs/index.html` (the GitHub Pages landing page) links to the **latest** release and fills in the
version via the GitHub Releases API, so no manual edit is needed per release — once a tagged release
exists, the site's Download button points to its `.dmg` automatically.

## First-launch note for users

The app launches immediately after dragging to Applications, but window control only works after the
user enables Azimuth in **System Settings → Privacy & Security → Accessibility** (standard for this
class of app).
