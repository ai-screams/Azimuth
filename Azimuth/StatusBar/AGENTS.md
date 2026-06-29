<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-29 -->

# StatusBar

## Purpose
메뉴바 상태 항목과 그 메뉴. 권한 상태 표시, 설정 열기, 종료, DEBUG 진단/명령 서브메뉴를 제공한다.

## Key Files
| File | Description |
|------|-------------|
| `StatusBarController.swift` | `@MainActor`, `NSMenuDelegate`. 컴팩트 SF Symbol 상태 아이콘(권한 시 `macwindow.on.rectangle`, 필요 시 `exclamationmark.triangle`). 메뉴: 권한 상태/Accessibility 설정 열기/Check for Updates…/Open Settings(`⌘,`)/Quit(`⌘q`). DEBUG: 포커스 창 식별 + 33개 명령 서브메뉴(`WindowCommand.menuCommands`) |

## For AI Agents

### Working In This Directory
- 권한 상태는 `menuWillOpen`과 `refreshPermissionState`에서 갱신(앱 활성화 시 `AppDelegate`가 호출).
- DEBUG 전용 진단은 `#if DEBUG`로 감싼다(RELEASE 메뉴에 노출 금지).
- 메뉴바 아이콘은 SF Symbol(템플릿 이미지)이라 별도 에셋 불필요. 꽉 찬 메뉴바+멀티디스플레이에서 macOS가 항목을 숨길 수 있음(앱 제어 밖, 환경 한계).

### Testing Requirements
- `make run`으로 메뉴바 항목 표시·권한 색상 전환·DEBUG 명령 서브메뉴 동작 확인.

### Common Patterns
- 명령 실행은 단축키와 동일하게 `Commands/WindowCommandExecutor.run`을 통함(경로 단일화). 실패 시 비프 + 로그.

## Dependencies

### Internal
- `Permissions/AccessibilityPermissionService`, `Commands/WindowCommandExecutor`·`WindowCommand`, `WindowAccess/FrontmostAppTracker`·`FocusedWindowResolver`·`WindowUndoStore`, `Shared/Log`.

### External
- Cocoa(NSStatusBar/NSMenu), os.

<!-- MANUAL: -->
