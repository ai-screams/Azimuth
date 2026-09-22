<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# Permissions

## Purpose
Accessibility(AX) 권한 상태 조회·요청·System Settings 안내. **정공법**(공식 API)으로만 권한을 다룬다.

## Key Files
| File | Description |
|------|-------------|
| `AccessibilityPermissionService.swift` | `@MainActor`. `currentStatus()`(캐시된 `AXIsProcessTrusted`), `invalidateCache()`, `requestPrompt()`(`AXIsProcessTrustedWithOptions` + prompt, 반환값 없음 — 프롬프트 직후 상태는 사용자가 조작하기 전 값이라 무의미), `openSystemSettings()`(Privacy_Accessibility URL), **`promptAndOpenSettings()`**(둘을 합친 것 — "권한 설정 열기" 버튼/메뉴가 쓰는 유일한 경로. 설정창과 상태바가 같은 다섯 줄을 복제하던 것을 합쳤다. 실패 시 비프는 UI 몫이라 호출부에 남긴다). `AccessibilityPermissionStatus`(granted/required + 메뉴·설정창 표시 텍스트) |

## For AI Agents

### Working In This Directory
- **권한 우회·검사 무력화 절대 금지.** 권한은 공식 API로 요청하고 사용자가 System Settings에서 부여하게 한다.
- 권한이 "꼬이는" 근본 원인은 보통 **코드 서명 정체성 불일치**(ad-hoc 빌드). 코드가 아니라 서명/빌드 경로(`make run`)로 해결한다.

### Testing Requirements
- `make run`(Apple Dev 서명)으로 실행해야 TCC 권한이 유지된다. 상태 토글 후 메뉴/설정창의 🟢/🟠 갱신 확인.

### Common Patterns
- 권한 상태를 읽기/쓰기 경계 모두에서 가드(`WindowAccess`)하고, UI는 `didBecomeActive`/표시 시점에 재조회.
- **명령 경로는 캐시를 다시 읽어 판정하지 않는다.** 캐시 무효화 지점이 앱 활성화·메뉴 열기 둘뿐이라,
  권한 안내가 필요한 순간(앱이 비활성이고 메뉴도 닫힌 채 단축키를 누를 때)은 정확히 그 둘 다 일어나지
  않은 때다. 예전에 이 자리에서 `currentStatus()`를 읽어 안내를 건너뛰던 결함이 있었다. 안내 여부는
  `Commands/CommandFeedbackPolicy`가 **에러**(`.resolution(.permissionDenied)`)로 판정한다.
- 반대 방향(권한을 켰는데 캐시가 `false`)은 `WindowCommandExecutor.run`이 닫는다 — 권한 거부를 만나면
  캐시를 갱신하고 **새 값이 trusted 일 때만** 한 번 재실행한다. 캐시를 없애면 명령마다 동기 tccd 호출이
  메인스레드에 올라가므로, 고칠 곳은 캐시가 아니라 소비자다.

## Dependencies

### Internal
- `StatusBar`·`Settings`(상태 표시), `WindowAccess`(읽기/쓰기 가드).

### External
- ApplicationServices(AX), Cocoa(NSWorkspace).

<!-- MANUAL: -->
