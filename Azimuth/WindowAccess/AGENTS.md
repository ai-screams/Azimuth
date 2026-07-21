<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-29 -->

# WindowAccess

## Purpose
Accessibility(AX) API와 직접 맞닿는 계층. "어느 앱/어느 창"을 해석하고, 창 frame을 읽고 쓰고, 되돌리기 상태와 화면 작업영역을 계산한다. 명령 엔진(`Commands/`)이 이 계층을 통해 실제 창을 조작한다.

## Key Files
| File | Description |
|------|-------------|
| `FrontmostAppTracker.swift` | `@MainActor`. 직전 non-Azimuth 활성 앱 추적(`didActivateApplication` 옵저버). `targetApplication`으로 "명령 대상 앱" 정책을 한 곳에 모음 |
| `FocusedWindowResolver.swift` | `@MainActor`. 대상 앱의 `kAXFocusedWindowAttribute`를 `ResolvedWindow`로 해석. 권한·풀스크린(비공개 `AXFullScreen`)·최소화·subrole(`kAXStandardWindowSubrole`) 가드. AX 오류를 `WindowResolutionError`로 매핑 |
| `AXAttribute.swift` | `nonisolated`. AX 속성 얇은 래퍼 — 읽기(string/bool/element/point/size) + 쓰기(`set`: bool/point/size). 유일하게 범위 한정 force-cast 허용(`swiftlint:disable` 주석) |
| `WindowFrameWriter.swift` | `@MainActor`. AX position/size 쓰기. 실제 바뀌는 축의 권한만 요구·그 축만 쓰기(M-3), shrink일 때 size→position 순서(옆 모니터 침범 방지), 명시적 `anchor`로 실제 크기에 맞춰 고정 모서리 유지(M-4) + verify·1회 재시도. 성공·실패 양쪽에서 achieved를 실은 `FrameApplyResult` 회신(성공/실패는 쓰기 결과, 변화 여부는 Executor가 판정 — H-1). 애니메이션 억제는 `AnimationSuppressor`에 위임 |
| `AnimationSuppressor.swift` | `@MainActor`. 대상 앱의 `AXEnhancedUserInterface`/`AXManualAccessibility`를 쓰기 동안 끄고 마지막 입력 +0.25s에 원복(PID별 디바운스, 엘리먼트 동일성으로 PID 재사용 방어). VoiceOver 중엔 미적용. 깜빡임 1차 원인 제거 |
| `WindowUndoStore.swift` | `@MainActor`. 창별 1단계 직전 frame 저장(capacity 64, LRU). `AXUIElement`를 `CFEqual`/`CFHash`로 식별, pid 일치 확인(닫힌 창 element 재사용 오인 방지). `clearAll`은 디스플레이 재구성 시 호출 |
| `SnapStateStore.swift` | `@MainActor`. 창별 스냅 상태(`SnapRecord`: edge + 스냅 당시 frame) 저장(capacity 64, LRU, UndoStore와 동일 키 설계). snapThrow가 제약 앱을 "이미 스냅됨"으로 인식하고 외부 이동 시 무효화하는 데 쓴다(H-2). `clearAll`은 디스플레이 재구성 시 호출 |
| `WorkAreaResolver.swift` | `@MainActor`. AX 창 frame이 가장 많이 겹치는 화면의 `visibleFrame`을 AX 좌표로 반환(멀티모니터 대응) |
| `DisplayResolver.swift` | `@MainActor`. snapThrow·moveToDisplay 명령의 인접 디스플레이 타깃을 해석. 창 frame과 edge 방향으로 "던질 화면"을 결정해 `WindowCommandExecutor`에 제공 |
| `NSScreen+BestMatch.swift` | `NSScreen` 확장. 주어진 AX frame과 겹침이 가장 큰 화면을 반환하는 유틸리티(`bestMatch`). `DisplayResolver`·`WorkAreaResolver`가 공용으로 사용 |

## For AI Agents

### Working In This Directory
- 권한 가드를 **읽기·쓰기 양쪽**에 둔다(호출 순서에 의존하지 않게 방어적). 권한 검사를 제거/우회하지 말 것.
- 풀스크린은 subrole로 구분 불가 → subrole 검사보다 **먼저** 비공개 `AXFullScreen` 속성으로 판별(기존 동작 유지).
- AX 좌표(좌상단 원점)로 다룬다. 화면/Cocoa 변환이 필요하면 `Shared/CoordinateSpace` 사용.

### Testing Requirements
- 이 계층은 실제 AX 권한이 필요해 단위 테스트 대신 **`make run`(서명 빌드) 라이브 검증**. 순수 계산은 `Commands/FrameCalculator`로 분리되어 `make test`가 커버.

### Common Patterns
- `Result<_, WindowResolutionError>` / `Result<CGRect, WindowCommandError>`로 실패 사유를 구체화.
- `ResolvedWindow`(element/appElement/subrole/pid/frame)가 해석 결과의 단일 캐리어. `appElement`는 writer가 애니메이션 억제에 쓴다.

## Dependencies

### Internal
- `Permissions/AccessibilityPermissionService`(권한), `Shared/WindowFrame`·`WindowResolutionError`·`CoordinateSpace`, `Commands/WindowCommandError`.

### External
- ApplicationServices(AX), AppKit(NSScreen/NSWorkspace/NSRunningApplication).

<!-- MANUAL: -->
