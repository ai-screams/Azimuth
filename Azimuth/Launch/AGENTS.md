<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# Launch

## Purpose
로그인 자동 실행. macOS 공식 `ServiceManagement.SMAppService`로만 등록/해제한다(정공법, 권한 우회 없음).

## Key Files
| File | Description |
|------|-------------|
| `LaunchAtLoginService.swift` | `@MainActor`. `SMAppService.mainApp` 래퍼: `isEnabled`(status==.enabled), `requiresApproval`(status==.requiresApproval), `enable() throws`(`register()`), `disable(completion:)`(비동기 `unregister`, 완료 후 메인액터 콜백), `openSystemSettingsLoginItems()` |

## For AI Agents

### Working In This Directory
- **공식 SMAppService API만 사용.** 등록 실패·`requiresApproval` 시 우회하지 말고 `openSystemSettingsLoginItems()`로 사용자 승인을 유도한다.
- `unregister`는 비동기다. 직후 동기적으로 상태를 읽지 말고 completion 콜백 후 UI를 갱신(메인액터 hop). `register()`는 동기.
- SMAppService는 상태 변경 알림이 없다 → UI는 `didBecomeActive`/표시 시점 폴링으로 동기화(소비처 `ViewController` 참조).

### Testing Requirements
- `make run`(서명 빌드)으로 체크 후 **System Settings › 일반 › 로그인 항목**에 Azimuth 표시 확인. 서명이 안정적이어야 정상 동작.

### Common Patterns
- 에러는 호출부에서 로그+사용자 피드백. `enable() throws`는 `SMAppService.register()` 오류를 그대로 전파.

## Dependencies

### Internal
- 소비처: `Settings`(주입)·`ViewController`(토글 UI), `Shared/Log`.

### External
- ServiceManagement(SMAppService), os.

<!-- MANUAL: -->
