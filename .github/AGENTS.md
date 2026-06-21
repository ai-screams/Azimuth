<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# .github

## Purpose
GitHub Actions CI 설정.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `workflows/` | CI 워크플로(`ci.yml`) |

## Key Files
| File | Description |
|------|-------------|
| `workflows/ci.yml` | `push: main` + 모든 PR에서 실행. `macos-latest`. 잡: **secret-scan**(gitleaks, SARIF 업로드), **lint-and-build**(SwiftFormat `--lint` → SwiftLint strict → `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` → `scripts/test.sh`) |

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
