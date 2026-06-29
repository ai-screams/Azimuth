<!-- Generated: 2026-06-19 | Updated: 2026-06-29 -->

# Azimuth

## Purpose
Azimuth는 macOS 메뉴바 **윈도우 매니저**다 (Magnet/Rectangle 류). Accessibility(AX) API로 다른 앱의 포커스된 일반 창을 식별하고, 전역 단축키 또는 메뉴 명령으로 반분/1·2·3분할/최대화/이동/상대 변형/되돌리기를 수행한다. Swift + AppKit, 스토리보드 없는 프로그래매틱 진입(`Azimuth/main.swift`). Xcode 프로젝트(objectVersion 77, file-system synchronized group).

## Key Files
| File | Description |
|------|-------------|
| `Makefile` | `build`(ad-hoc 컴파일/CI 전용) · `run`(Apple Dev 서명, 권한 테스트용) · `lint` · `format` · `test` · `secrets` · `install-hooks` |
| `README.md` | 프로젝트 개요 |
| `Azimuth.xcodeproj` | Xcode 프로젝트. 비샌드박스, `DEVELOPMENT_TEAM=7K6MK3KP9K`, `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, deployment target macOS 26.3 |
| `.swiftlint.yml` | SwiftLint strict 설정 |
| `.swiftformat` | SwiftFormat 설정 (pre-commit + CI에서 `--lint`) |
| `.gitleaks.toml` | 시크릿 스캔 규칙 |
| `.gitignore` | `.docs/`, `.omc/` 등 제외 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Azimuth/` | 앱 소스 전체 (see `Azimuth/AGENTS.md`) |
| `Tests/` | 명령 엔진 순수 로직 회귀 테스트 (see `Tests/AGENTS.md`) |
| `scripts/` | build/run/lint/format/test/secret-scan 쉘 스크립트 (see `scripts/AGENTS.md`) |
| `.github/` | GitHub Actions CI (see `.github/AGENTS.md`) |
| `.githooks/` | `pre-commit`(SwiftFormat --lint + SwiftLint). `make install-hooks`로 설치 |

## For AI Agents

### Working In This Directory
- **권한/보안은 절대 우회하지 말 것**(정공법). AX 권한은 공식 API로 요청하고 사용자가 System Settings에서 부여하게 한다. `tccutil reset`(Apple 공식)은 허용.
- **권한 테스트는 `make run`(Apple Dev 서명)으로.** `make build`는 `CODE_SIGNING_ALLOWED=NO`(ad-hoc)라 cdhash가 바뀌어 TCC 권한이 초기화된다 → 컴파일/CI 검증 전용.
- `.docs/`는 내부 문서이며 **git에 커밋·푸시 금지**(gitignore됨).
- 소스 추가는 `Azimuth/` 아래에 두면 file-system synchronized group으로 **자동 포함**된다(pbxproj 수정 불필요). 단, 새 타깃/의존성 추가는 pbxproj/GUI 필요.

### Testing Requirements
- 변경 후 항상: `make build` → `make lint` → `make test`. 머지 전 통과 필수(CI가 동일하게 검사).
- 순수 로직 변경은 `make test`(swiftc 직접 컴파일, 통과 시 `PASS — all N checks` 출력)로 빠르게 회귀 확인.
- launch/Info.plist/타깃 설정 변경은 "프로세스 생존"만 보지 말고 **창이 실제로 뜨는지** 확인(과거 storyboard 제거가 delegate 연결을 끊은 회귀 있었음).

### Common Patterns
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` → 모든 타입이 기본 `@MainActor`. 순수/스레드 무관 로직은 명시적으로 `nonisolated`로 표시.
- 창 좌표는 내부적으로 **AX 좌표(좌상단 원점, Y 아래로)** 로 다루고, 화면 작업영역 변환 시 `Shared/CoordinateSpace`로 Cocoa↔AX 뒤집기.
- SwiftLint strict: force-unwrap/force-cast 금지(예외: `WindowAccess/AXAttribute`의 범위 한정 CF 캐스트 + `swiftlint:disable` 주석). function/type body length, line 120 제한.

## Dependencies

### Internal
- 명령 실행 데이터 흐름: 단축키/메뉴 → `Commands/WindowCommandExecutor` → `WindowAccess`(앱/창 해석·쓰기) + `Commands/FrameCalculator`(기하) + `WindowAccess/WindowUndoStore`(되돌리기).

### External
- AppKit / Cocoa, ApplicationServices(AX), CoreGraphics, Carbon.HIToolbox(전역 단축키), ServiceManagement(로그인 자동 실행).
- **Sparkle 2** (SPM, 2.9.3, revision `d46d456`): 자동 업데이트 프레임워크. `AppDelegate`의 `SPUStandardUpdaterController`로 초기화; "Check for Updates…" 메뉴 항목(App 메뉴·상태바 메뉴·Settings Updates 카드)의 타깃이 된다.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
