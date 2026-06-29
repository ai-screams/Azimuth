<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-29 -->

# .github

## Purpose
GitHub Actions CI/CD 설정. **전체 개요·보안 레이어·활성화 설정은 [`CICD.md`](CICD.md) 참조.**

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `workflows/` | `ci.yml`(통합 검사) · `codeql.yml`(SAST) · `release.yml`(릴리스) |

## Key Files
| File | Description |
|------|-------------|
| `CICD.md` | CI/CD 전체 문서(워크플로·방어 레이어·로컬 대응·저장소 설정·릴리스 방법) |
| `workflows/ci.yml` | `push: main`+PR, `macos-15`. **secret-scan**(gitleaks+SARIF) · **lint-and-build**(SwiftFormat→SwiftLint strict→xcodebuild→`scripts/test.sh`→`make coverage` ≥90% 게이트). concurrency로 PR stale 취소 |
| `workflows/codeql.yml` | CodeQL **Swift** SAST(push: main·주간). init→빌드→analyze → Security/Code scanning |
| `workflows/release.yml` | 태그 `v*` → `environment: release` 승인 게이트 → 빌드·서명·공증·**DMG 자가검증**·**SHA-256 체크섬**·**EdDSA 서명키 일치 게이트**·**Sparkle appcast 서명·생성**·Release 발행 |
| `dependabot.yml` | github-actions 주간 업데이트(SHA 핀 갱신) |

## For AI Agents

### Working In This Directory
- CI는 로컬 `make lint`/`make build`/`make test`와 동일 검사다. 머지 전 로컬에서 먼저 green 확인하면 CI 실패를 예방한다.
- CI 빌드는 `CODE_SIGNING_ALLOWED=NO`(ad-hoc, 서명 불필요) — 컴파일 검증 목적. 권한 동작은 CI에서 검증 불가(로컬 `make run`).
- 시크릿이 코드에 들어가지 않게 한다(gitleaks가 차단). `.docs/`는 커밋하지 않는다.

### Testing Requirements
- 워크플로 변경 시 PR을 열어 Actions 결과로 검증.

### Common Patterns
- `continue-on-error`로 gitleaks 결과를 SARIF 업로드 후 별도 스텝에서 실패 판정.

## Dependencies

### External
- GitHub Actions, brew(gitleaks/swiftlint/swiftformat), xcodebuild.

<!-- MANUAL: -->
