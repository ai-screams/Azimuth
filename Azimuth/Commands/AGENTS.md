<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-07-01 -->

# Commands

## Purpose
명령 엔진. **무엇을** 할지(명령 모델), **어디로** 할지(순수 기하 계산), 그리고 실제 **실행 오케스트레이션**을 담는다. 모델과 계산은 AppKit/AX에 의존하지 않는 순수 로직이라 `Tests/`에서 `swiftc`로 독립 컴파일된다.

## Key Files
| File | Description |
|------|-------------|
| `CommandPrimitives.swift` | `nonisolated` 빌딩블록 값 타입: `Axis`/`Fraction`/`Slot`/`AbsolutePlacement`/`MoveDirection`/`RelativeAnchor`/`SnapEdge`(표시명·안정 토큰) + `FrameAnchor`(고정 모서리 의도)·`SnapRecord`(창별 스냅 상태 값). `WindowCommand.swift`에서 분리(파일 비대화 방지) |
| `WindowCommand.swift` | `nonisolated` 명령 모델: `WindowCommand`(maximize/absolute/snapThrow/moveToDisplay/move/relativeHalf/relativeTwoThird/undo) + `CommandGroup`(core/halves/thirds/twoThirds/move/relative/display) + 명령별 `frameAnchor`(고정 모서리) + 식별자 역조회 + `menuCommands` 목록(34개) |
| `FrameCalculator.swift` | `nonisolated` 순수 기하. AX 좌표 입력(current, workArea)으로 목표 frame 계산. 절대 배치(축 독립), 이동(현재 크기 유지·작업영역 클램프), 상대 반분/2/3(현재 frame 기준 edge 고정), snapThrow/moveToDisplay 지원(`halfRect`·`isAlreadySnapped`·`displayMoveRect`), anchor 계산(`anchoredOrigin`), 여백 최대화(`gappedWorkArea`), 제약 앱·유효 frame 판정(`isConstrained`·`isUsableFrame`) |
| `FrameApply.swift` | `nonisolated` 순수 판정. AX 쓰기 결과 해석과 무관한 기하 판정을 모은다: `changed`(achieved가 pre에서 변했나 — Undo), `reached`(target 도달 — 재시도·복원 확인), `movesOrigin`/`resizesSize`(축별 변경 — 권한·쓰기 최소화). Writer가 AX 결과·읽은 frame을 값으로 넘겨 사용 |
| `DisplayGeometry.swift` | `nonisolated` 순수 기하. 인접 디스플레이 선택(`selectAdjacentIndex(current:candidates:window:edge:)`): 방향 판정·수직/주축 간격·거리·겹침으로 후보 중 최적 화면 인덱스 산출. AX 계층(`WindowAccess/DisplayResolver`)에서 분리해 테스트 가능하게 함 |
| `WindowCommandExecutor.swift` | `@MainActor` 오케스트레이션. 창 해석 → 작업영역 해석 → 목표·스냅 계획(`snapStore`) → AX 쓰기(`anchor`) → achieved 기준 Undo 기록·스냅 상태 기록. `FrameApplyResult`를 `Result<CGRect, WindowCommandError>`로 매핑 |

## For AI Agents

### Working In This Directory
- `CommandPrimitives.swift`·`WindowCommand.swift`·`FrameCalculator.swift`·`DisplayGeometry.swift`는 **AppKit/AX import 금지**(순수 로직 유지). 이들은 `scripts/test.sh`·`scripts/coverage.sh`가 직접 컴파일하므로 import를 추가하면 테스트/커버리지 빌드가 깨진다(CoreGraphics는 허용).
- 새 명령 추가 시: `WindowCommand`에 케이스 + `displayName`, `FrameCalculator.targetFrame`에 분기, 필요하면 `menuCommands`와 `Hotkeys/HotkeyPreset` 바인딩에도 추가.
- 모든 frame은 **AX 좌표(좌상단 원점)** 기준. Cocoa 변환은 호출부(`WorkAreaResolver`)에서 처리됨.

### Testing Requirements
- `make test`(`Tests/CommandEngineTests.swift`)가 절대 배치/축 합성/이동/상대 반분/상대 2/3/snapThrow·displayMove/여백 최대화·고정폭 판정/인접 디스플레이 선택/명령 모델(34개)을 검증. 기하 변경 시 케이스 추가. 순수 로직 라인 커버리지는 `make coverage`(≥90%)로 게이트.

### Common Patterns
- 이동 클램프: 창이 작업영역보다 크면(`upper < lower`) 좌상단(`lower`)에 고정.
- `WindowCommandExecutor`는 일반 명령 적용 직전에 `WindowUndoStore.record`로 1단계 되돌리기 상태 저장. undo는 소비 후 entry 제거.

## Dependencies

### Internal
- `WindowAccess/FocusedWindowResolver`(창 해석), `WindowAccess/WindowFrameWriter`(AX 쓰기), `WindowAccess/WorkAreaResolver`(작업영역), `WindowAccess/WindowUndoStore`, `WindowAccess/FrontmostAppTracker`, `Shared/WindowCommandError`.

### External
- CoreGraphics(모델·계산), Cocoa(실행기).

<!-- MANUAL: -->
