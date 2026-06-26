<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# Commands

## Purpose
명령 엔진. **무엇을** 할지(명령 모델), **어디로** 할지(순수 기하 계산), 그리고 실제 **실행 오케스트레이션**을 담는다. 모델과 계산은 AppKit/AX에 의존하지 않는 순수 로직이라 `Tests/`에서 `swiftc`로 독립 컴파일된다.

## Key Files
| File | Description |
|------|-------------|
| `CommandPrimitives.swift` | `nonisolated` 빌딩블록 값 타입: `Axis`/`Fraction`/`Slot`/`AbsolutePlacement`/`MoveDirection`/`RelativeAnchor`/`SnapEdge`(표시명·안정 토큰). `WindowCommand.swift`에서 분리(파일 비대화 방지) |
| `WindowCommand.swift` | `nonisolated` 명령 모델: `WindowCommand`(maximize/absolute/snapThrow/moveToDisplay/move/relativeHalf/undo) + `CommandGroup`(논리 그룹) + 식별자 역조회 + DEBUG `menuCommands` 목록(29개) |
| `FrameCalculator.swift` | `nonisolated` 순수 기하. AX 좌표 입력(current, workArea)으로 목표 frame 계산. 절대 배치(축 독립), 이동(현재 크기 유지·작업영역 클램프), 상대 반분(현재 frame 기준 edge 고정) |
| `WindowCommandExecutor.swift` | `@MainActor` 오케스트레이션. 창 해석 → (undo면 복원, 아니면 직전 frame 기록) → 작업영역 해석 → 목표 계산 → AX 쓰기. `Result<CGRect, WindowCommandError>` 반환 |

## For AI Agents

### Working In This Directory
- `CommandPrimitives.swift`·`WindowCommand.swift`·`FrameCalculator.swift`는 **AppKit/AX import 금지**(순수 로직 유지). 이 셋은 `scripts/test.sh`가 직접 컴파일하므로 import를 추가하면 테스트 빌드가 깨진다(CoreGraphics는 허용).
- 새 명령 추가 시: `WindowCommand`에 케이스 + `displayName`, `FrameCalculator.targetFrame`에 분기, 필요하면 `menuCommands`와 `Hotkeys/HotkeyPreset` 바인딩에도 추가.
- 모든 frame은 **AX 좌표(좌상단 원점)** 기준. Cocoa 변환은 호출부(`WorkAreaResolver`)에서 처리됨.

### Testing Requirements
- `make test`(`Tests/CommandEngineTests.swift`)가 절대 배치/축 합성/이동/상대 반분/모델을 검증. 기하 변경 시 케이스 추가.

### Common Patterns
- 이동 클램프: 창이 작업영역보다 크면(`upper < lower`) 좌상단(`lower`)에 고정.
- `WindowCommandExecutor`는 일반 명령 적용 직전에 `WindowUndoStore.record`로 1단계 되돌리기 상태 저장. undo는 소비 후 entry 제거.

## Dependencies

### Internal
- `WindowAccess/FocusedWindowResolver`(창 해석), `WindowAccess/WindowFrameWriter`(AX 쓰기), `WindowAccess/WorkAreaResolver`(작업영역), `WindowAccess/WindowUndoStore`, `WindowAccess/FrontmostAppTracker`, `Shared/WindowCommandError`.

### External
- CoreGraphics(모델·계산), Cocoa(실행기).

<!-- MANUAL: -->
