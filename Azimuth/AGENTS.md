<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# Azimuth (app source)

## Purpose
앱 소스 루트. 프로그래매틱 AppKit 진입(`main.swift`)에서 `AppDelegate`가 모든 컴포넌트를 조립한다: 상태바 항목, 전역 단축키, 설정창, 권한 추적. 기능별 하위 디렉터리로 나뉜다.

## Key Files
| File | Description |
|------|-------------|
| `main.swift` | 스토리보드 없는 표준 진입점. `MainActor.assumeIsolated`로 `NSApplication`에 `AppDelegate`를 명시적으로 연결해 실행 |
| `AppDelegate.swift` | 컴포지션 루트. 트래커/언두스토어/핫키서비스/프리퍼런스/설정창/상태바를 보유, `applicationDidFinishLaunching`에서 설치·핫키 reload·옵저버 등록. 단축키 명령 디스패치(`runHotkeyCommand`) |
| `ViewController.swift` | 설정창 내용(프로퍼티·생명주기·상태 갱신). Permissions/Shortcuts/Behavior 섹션. 레이아웃·서브뷰 팩토리는 `ViewController+Layout.swift`, `@objc` 액션은 `ViewController+Actions.swift`로 분리 |
| `FlippedView.swift` / `NSButton+Rounded.swift` | 공용 보조: 뒤집힌 스크롤 문서 뷰, 둥근(.rounded) 버튼 팩토리 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Commands/` | 명령 모델 + 기하 계산 + 실행 오케스트레이션 (see `Commands/AGENTS.md`) |
| `WindowAccess/` | AX로 앱/창 해석·frame 읽기쓰기·되돌리기·작업영역 (see `WindowAccess/AGENTS.md`) |
| `Hotkeys/` | Carbon 전역 단축키 + 프리셋(Standard/Vim) (see `Hotkeys/AGENTS.md`) |
| `Shared/` | 좌표 변환·값 타입·에러·로그 (see `Shared/AGENTS.md`) |
| `Permissions/` | Accessibility 권한 상태·요청 (see `Permissions/AGENTS.md`) |
| `Preferences/` | UserDefaults 래퍼 (see `Preferences/AGENTS.md`) |
| `Settings/` | 설정창 윈도우 컨트롤러 (see `Settings/AGENTS.md`) |
| `StatusBar/` | 메뉴바 상태 항목·메뉴 (see `StatusBar/AGENTS.md`) |
| `Launch/` | 로그인 자동 실행(SMAppService) (see `Launch/AGENTS.md`) |
| `Assets.xcassets` | 앱 아이콘·액센트 컬러(에셋 카탈로그). 메뉴바 아이콘은 SF Symbol 사용이라 별도 에셋 불필요 |

## For AI Agents

### Working In This Directory
- 새 의존성은 `AppDelegate`에서 생성·주입한다. 컴포넌트는 생성자 주입(DI)으로 연결되어 있다(예: 설정창에 `PreferencesStore`/`LaunchAtLoginService` 주입).
- 진입/와이어링(`main.swift`/`AppDelegate`)을 건드리면 **창이 실제로 뜨는지** 확인. `@main`만으로는 delegate가 안 붙는다(스토리보드 없음).
- DEBUG 빌드는 활성화 정책 `.regular` + 기동 시 설정창 자동 표시, RELEASE는 `.accessory`(메뉴바 전용).

### Testing Requirements
- `make build` + `make lint` + `make test`. 권한 동작 확인은 `make run`(서명 빌드).

### Common Patterns
- 기본 `@MainActor`. 순수 값/로직 타입은 `nonisolated`(예: `Commands`·`Shared`의 enum/struct).
- 명령 실행은 `Commands/WindowCommandExecutor.run(_:tracker:undoStore:)` 한 경로로 모인다(단축키와 DEBUG 메뉴가 공유).

## Dependencies

### Internal
- `AppDelegate` → 모든 서브시스템. 실행 경로는 `Commands/AGENTS.md` 참조.

### External
- AppKit, ApplicationServices, Carbon.HIToolbox, ServiceManagement, os(Logger).

<!-- MANUAL: -->
