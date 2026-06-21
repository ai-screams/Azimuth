<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# scripts

## Purpose
빌드/실행/품질/보안 작업의 쉘 스크립트. `Makefile` 타깃이 이들을 호출한다.

## Key Files
| File | Description |
|------|-------------|
| `build.sh` | `xcodebuild ... CODE_SIGNING_ALLOWED=NO build`. **ad-hoc 산출물 → 컴파일/CI 검증 전용**(권한 테스트엔 부적합) |
| `run.sh` | Apple Development 서명(`CODE_SIGN_STYLE=Automatic`, `DEVELOPMENT_TEAM` env 재정의 가능)으로 빌드 후 `.app` 실행. **권한 필요한 실행/테스트는 반드시 이걸로**(안정 DR → TCC 권한 유지) |
| `test.sh` | `swiftc`로 명령 엔진 순수 로직(`FrameCalculator`+`WindowCommand`+`Tests`) 컴파일·실행 |
| `lint.sh` | `swiftlint lint --strict --no-cache --config .swiftlint.yml` |
| `format.sh` | SwiftFormat 실행 |
| `secret-scan.sh` | gitleaks 시크릿 스캔 |
| `install-hooks.sh` | `.githooks/pre-commit`을 git hooks로 설치 |

## For AI Agents

### Working In This Directory
- **`build` vs `run` 구분이 핵심.** `build.sh`는 ad-hoc(cdhash 불안정 → TCC 권한 꼬임), `run.sh`는 안정 서명. 권한 동작 검증은 `make run`.
- `run.sh`는 산출물 경로를 빌드 설정(`BUILT_PRODUCTS_DIR`/`FULL_PRODUCT_NAME`)에서 읽는다 — 경로 하드코딩 금지.
- 스크립트는 `set -euo pipefail`(test.sh는 종료코드 보존 위해 `-uo`) + `ROOT_DIR` 기준 경로 패턴 유지.

### Testing Requirements
- 변경 후 해당 `make` 타깃으로 직접 실행해 동작 확인.

### Common Patterns
- zsh, `ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"`로 루트 고정.

## Dependencies

### External
- xcodebuild, swiftc, swiftlint, swiftformat, gitleaks(brew).

<!-- MANUAL: -->
