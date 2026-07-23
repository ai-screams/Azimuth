<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-07-23 -->

# Shared

## Purpose
여러 계층이 공유하는 좌표 변환, 값 타입, 에러, 로깅 유틸.

## Key Files
| File | Description |
|------|-------------|
| `CoordinateSpace.swift` | `@MainActor`. AX(좌상단 원점, Y↓) ↔ Cocoa(좌하단 원점, Y↑) 사각형 변환. **전역 원점(0,0)을 소유한 디스플레이** 높이를 기준으로 Y를 뒤집는 involution(`flip`이 양방향 공통). `axWorkArea(of:)`로 NSScreen visibleFrame→AX 작업영역 변환(0 크기 가드 포함, `WorkAreaResolver`·`WindowAccess/DisplayResolver` 공유) |
| `BundleVersion.swift` | `Bundle` 확장 `displayVersion(prefix:)`. `CFBundleShortVersionString`(+빌드)를 표시용 버전 문자열로 조합. `AboutWindowController`·`ViewController`가 공유(버전 문자열 중복 제거) |
| `WindowFrame.swift` | `nonisolated`. `WindowFrame`(origin/size→rect) 값 타입 + `WindowResolutionError`(권한/풀스크린/subrole/messaging-timeout/AX 코드 등 + 영어 `userFacingMessage`) |
| `WindowCommandError.swift` | `nonisolated`. 명령 실행 상위 에러(`resolution`/`workAreaUnavailable`/`notMovable`/`applyFailed`/`noUndoState`) + `userFacingMessage` |
| `Log.swift` | `os.Logger` 카테고리(`app`, `windows`), subsystem `com.aiscream.Azimuth` |

## For AI Agents

### Working In This Directory
- `CoordinateSpace`의 기준 높이는 `NSScreen.screens.first`가 아니라 **원점을 가진 디스플레이**다(멀티모니터에서 first가 주 디스플레이 보장 없음). 이 가정을 깨지 말 것.
- 사용자 노출 문자열은 에러 enum의 `userFacingMessage`에 모음(영어 — 상태바 메뉴·알림에 그대로 노출, 현지화는 추후 일괄). 새 실패 사유는 여기에 케이스+메시지 추가.
- `os.Logger` 출력은 이 환경의 `log show`로 안 잡힌다. 진단 시 직접 실행 stderr 또는 CGWindowList 활용.

### Testing Requirements
- 순수 값/에러 타입. `make build`로 컴파일 확인. 좌표 변환은 라이브(`make run`)로 검증.

### Common Patterns
- 에러는 `Equatable` enum으로 분기 명확화. 표시명/메시지는 computed property.

## Dependencies

### Internal
- 거의 모든 계층이 의존(에러·좌표·로그).

### External
- AppKit(NSScreen), CoreGraphics, Foundation, os.

<!-- MANUAL: -->
