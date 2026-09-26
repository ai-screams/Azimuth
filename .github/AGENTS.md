<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# .github

## Purpose
GitHub Actions CI/CD configuration. **See [`CICD.md`](CICD.md) for the full overview, the security layers and the repository settings.**

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `workflows/` | `ci.yml` (combined checks) · `codeql.yml` (SAST) · `release-legacy.yml` (legacy releases; this branch has no `release.yml`) |

## Key Files
| File | Description |
|------|-------------|
| `CICD.md` | The complete CI/CD document (workflows, defense layers, local equivalents, repository settings, how to release) |
| `workflows/ci.yml` | **Legacy branch:** push to and PRs into `legacy/10.13`, on `macos-15` with Xcode **26.3** pinned and asserted. **secret-scan** (gitleaks + SARIF) and **lint-and-build** (SwiftFormat → SwiftLint strict → xcodebuild Debug + Release → unsigned legacy bundle gate → Sparkle version-displayer check → `make coverage` with the ≥90% gate). Concurrency cancels stale PR runs |
| `workflows/codeql.yml` | CodeQL **Swift** SAST on push to `legacy/10.13` (Xcode 26.3; no schedule — GitHub runs schedules only from the default branch). init → build → analyze → Security/Code scanning |
| `workflows/release-legacy.yml` | **Legacy branch.** Tag `legacy-vX.Y.Z-N` → approval → main-latest assertion → `release.sh` (runtime bundling + signed gate + notarization) → DMG checks, EdDSA key match → Sparkle version-order gate → appcast pinned to macOS 10.13.0–12.99.99 → version release with `make_latest: false` → `legacy-feed` release's `appcast.xml` replaced → main latest unchanged. Two jobs: `build` (read-only token, `release` environment and signing secrets) and `publish` (write token, no secrets). Tag `legacy-rc-vX.Y.Z-N` is the **RC**: `build` only, the notarized DMG and appcast stay as Actions artifacts — no release or feed change, and the read-only token cannot publish. (Not `workflow_dispatch`: that needs the file on the default branch.) Details: `CICD.md` "레거시 브랜치" |
| `dependabot.yml` | Weekly github-actions updates (refreshing the SHA pins) |
| `FUNDING.yml` | The source for the repo's ♡ Sponsor button: `github: [ai-screams]` (organization Sponsors) + `ko_fi: pignuante`. The button also requires the repo's **Settings → Features → Sponsorships** toggle |
| `CODEOWNERS` | Code owners (automatic reviewer assignment) |
| `PULL_REQUEST_TEMPLATE.md` | The default PR body template |

## For AI Agents

### Working In This Directory
- CI runs the same checks as local `make lint` / `make build` / `make test`. Getting them green locally before merging prevents CI failures.
- CI builds with `CODE_SIGNING_ALLOWED=NO` (ad-hoc, no signing needed) because its purpose is compile verification. Permission behavior cannot be verified in CI — use local `make run`.
- Keep secrets out of the code (gitleaks blocks them). Never commit `.docs/`.

### Testing Requirements
- When changing a workflow, open a PR and verify it through the Actions result.

### Common Patterns
- gitleaks runs with `continue-on-error` so its SARIF can be uploaded, and a separate step decides the failure.

## Dependencies

### External
- GitHub Actions, brew (gitleaks / swiftlint / swiftformat), xcodebuild.

<!-- MANUAL: -->
