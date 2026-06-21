<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# Permissions

## Purpose
Accessibility(AX) 권한 상태 조회·요청·System Settings 안내. **정공법**(공식 API)으로만 권한을 다룬다.

## Key Files
| File | Description |
|------|-------------|
| `AccessibilityPermissionService.swift` | `nonisolated`. `currentStatus()`(`AXIsProcessTrusted`), `requestPrompt()`(`AXIsProcessTrustedWithOptions` + prompt), `openSystemSettings()`(Privacy_Accessibility URL). `AccessibilityPermissionStatus`(granted/required + 메뉴·설정창 표시 텍스트) |

## For AI Agents

### Working In This Directory
- **권한 우회·검사 무력화 절대 금지.** 권한은 공식 API로 요청하고 사용자가 System Settings에서 부여하게 한다.
- 권한이 "꼬이는" 근본 원인은 보통 **코드 서명 정체성 불일치**(ad-hoc 빌드). 코드가 아니라 서명/빌드 경로(`make run`)로 해결한다.

### Testing Requirements
- `make run`(Apple Dev 서명)으로 실행해야 TCC 권한이 유지된다. 상태 토글 후 메뉴/설정창의 🟢/🟠 갱신 확인.

### Common Patterns
- 권한 상태를 읽기/쓰기 경계 모두에서 가드(`WindowAccess`)하고, UI는 `didBecomeActive`/표시 시점에 재조회.

## Dependencies

### Internal
- `StatusBar`·`Settings`(상태 표시), `WindowAccess`(읽기/쓰기 가드).

### External
- ApplicationServices(AX), Cocoa(NSWorkspace).

<!-- MANUAL: -->
