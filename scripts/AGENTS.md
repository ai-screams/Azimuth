<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-07-01 -->

# scripts

## Purpose
빌드/실행/품질/보안/릴리스 작업의 쉘 스크립트. `Makefile` 타깃이 이들을 호출한다.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `dmg/` | DMG 배경 이미지(`background.png`/`background@2x.png`) — `make-dmg-background.swift`가 생성, `release.sh`가 DMG 스테이징에 사용 |

## Key Files
| File | Description |
|------|-------------|
| `build.sh` | `xcodebuild ... CODE_SIGNING_ALLOWED=NO build`. **ad-hoc 산출물 → 컴파일/CI 검증 전용**(권한 테스트엔 부적합) |
| `run.sh` | Apple Development 서명(`CODE_SIGN_STYLE=Automatic`, `DEVELOPMENT_TEAM` env 재정의 가능)으로 빌드 후 `.app` 실행. **권한 필요한 실행/테스트는 반드시 이걸로**(안정 DR → TCC 권한 유지) |
| `harness-sources.sh` | **컴파일 대상 목록의 단일 출처**(`HARNESS_SRC`·`HARNESS_TESTS`). `test.sh`·`coverage.sh`가 source 한다 — 새 순수 파일은 여기 한 곳만 추가. 배열만 정의하고 `set` 줄을 넣지 않는다(아래 참조) |
| `test.sh` | `harness-sources.sh`의 목록을 `swiftc`로 컴파일·실행. 종료코드를 그대로 전달 |
| `coverage.sh` | **같은 목록**을 `swiftc -profile-generate`로 빌드·실행해 llvm-cov 라인 커버리지 측정. 게이트 **≥90%**(`COVERAGE_MIN` env로 조정) |
| `lint.sh` | `swiftlint lint --strict --no-cache --config .swiftlint.yml` |
| `format.sh` | SwiftFormat 실행 |
| `secret-scan.sh` | gitleaks 시크릿 스캔 |
| `install-hooks.sh` | `.githooks/pre-commit`을 git hooks로 설치 |
| `release.sh` | 릴리스 파이프라인: archive→서명→공증(notarize)→DMG 생성·스테이징. `make release` / `release.yml`에서 호출 |
| `make-dmg-background.swift` | DMG 배경 이미지를 코드로 생성(`swiftc` 실행 스크립트) |

## For AI Agents

### Working In This Directory
- **`build` vs `run` 구분이 핵심.** `build.sh`는 ad-hoc(cdhash 불안정 → TCC 권한 꼬임), `run.sh`는 안정 서명. 권한 동작 검증은 `make run`.
- `run.sh`는 산출물 경로를 빌드 설정(`BUILT_PRODUCTS_DIR`/`FULL_PRODUCT_NAME`)에서 읽는다 — 경로 하드코딩 금지.
- 스크립트는 `set -euo pipefail`(test.sh·coverage.sh는 종료코드 보존 위해 `-uo`) + `ROOT_DIR` 기준 경로 패턴 유지.
- `harness-sources.sh`는 **배열만 정의한다. `set` 줄을 넣지 말 것** — `source`는 호출자 셸에서 실행되므로 `-e`가 두 스크립트에 주입되어 위의 의도적 선택이 조용히 깨진다.

### Testing Requirements
- 변경 후 해당 `make` 타깃으로 직접 실행해 동작 확인.

### Common Patterns
- zsh, `ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"`로 루트 고정.

## Dependencies

### External
- xcodebuild, swiftc, swiftlint, swiftformat, gitleaks(brew).

<!-- MANUAL: -->
