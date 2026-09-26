<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# .github

## Purpose
GitHub Actions CI/CD configuration. **See [`CICD.md`](CICD.md) for the full overview, the security layers and the repository settings.**

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `workflows/` | `ci.yml` (combined checks) · `codeql.yml` (SAST) · `release.yml` (releases) |

## Key Files
| File | Description |
|------|-------------|
| `CICD.md` | The complete CI/CD document (workflows, defense layers, local equivalents, repository settings, how to release) |
| `workflows/ci.yml` | `push: main` plus PRs, on `macos-15`. **secret-scan** (gitleaks + SARIF) and **lint-and-build** (SwiftFormat → SwiftLint strict → xcodebuild → Sparkle version-displayer check (`scripts/sparkle-adapter-check.sh`) → `make coverage` with the ≥90% gate). Concurrency cancels stale PR runs |
| `workflows/codeql.yml` | CodeQL **Swift** SAST (on push to main and weekly). init → build → analyze → Security/Code scanning |
| `workflows/release.yml` | Tag `v*` → the `environment: release` approval gate → build, sign, notarize, **DMG self-verification**, **SHA-256 checksum**, **EdDSA signing-key match gate**, **Sparkle appcast signing and generation**, then publish the Release |
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
