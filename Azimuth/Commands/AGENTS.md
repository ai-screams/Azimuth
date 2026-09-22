<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-21 -->

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
| `CommandOutcomePolicy.swift` | `nonisolated` 순수 상태 커밋 정책. 명령 전 frame·목표 frame·실제 AX 결과를 받아 Undo 기록과 Snap 상태의 keep/record/clear를 결정. 의도된 no-op과 AX가 성공을 반환했지만 쓰기를 무시한 경우를 `target`으로 구분 |
| `CommandPlanPolicy.swift` | `nonisolated` 순수 계획 정책. 명령·현재 frame·작업영역·스냅 기록·인접 작업영역(`CommandPlanInput`)을 받아 목표 frame과 이 명령 뒤 스냅될 edge(`CommandPlan`)를 결정. snapThrow 상태기계(안 스냅 → 스냅, 이미 스냅 → 인접의 반대쪽 절반으로 던지기, 인접 없음 → 제자리)와 moveToDisplay 목적지가 여기 있다. 인접 작업영역은 Executor가 `WindowCommand.adjacentEdge`로 조회해 값으로 넘긴다 |
| `DisplayGeometry.swift` | `nonisolated` 순수 기하. 두 질문에 답한다: 창이 지금 어느 화면에 있나(`bestMatchIndex(window:candidates:)` — 교집합 면적 → 동률이면 중심 포함 → 작은 displayID, 입력은 `ScreenCandidate`(frame + displayID), 반환은 `candidates` 원본 인덱스)와 그 화면의 어느 이웃으로 갈 것인가(`selectAdjacentIndex(current:candidates:window:edge:)` — 방향 판정·수직/주축 간격·거리·겹침). AX 계층(`WindowAccess/NSScreen+BestMatch`·`DisplayResolver`)은 `NSScreen` → 값 매핑만 한다 |
| `WriteRetryPolicy.swift` | `nonisolated` 순수 재시도 판정. 경과·예산·검증 결과(도달/미달/읽기 실패)·바뀌는 축 → position/size 각각 재시도할지. 경과는 **명령 시작** 기준이라 해석·억제가 쓴 시간이 예산에 들어간다. Foundation만 import |
| `ShortcutListPolicy.swift` | `nonisolated` 순수 표시 판정(설정창 Shortcuts 탭). 검색어·사용자가 펼친 그룹 → 그룹별 `ShortcutGroupDisplay`(헤더 표시/펼침/구분선). 검색 중엔 매칭 그룹을 자동으로 펼친다("검색했는데 결과가 접혀서 안 보임" 방지). Foundation만 import. |
| `CommandFeedbackPolicy.swift` | `nonisolated` 순수 판정. 명령 결과 + 사용자 설정(사운드/알림) + 세션 플래그 → `CommandFeedback`(마지막 실패 표시 `clear`/`keep`/`set` · 비프 · 알림 · 권한 안내). 권한 안내를 **에러 기준**으로 정해, `AccessibilityPermissionService` 캐시가 낡아 안내가 건너뛰어지던 결함을 없앤다. 에러 분기는 exhaustive(`default:` 없음) — 새 케이스가 생기면 빌드가 깨져 사용자에게 어떻게 보일지 결정하도록 강제한다. Foundation만 import |
| `WindowCommandExecutor.swift` | `@MainActor` 오케스트레이션. 창 해석 → 작업영역 해석 → 스냅 기록·인접 작업영역 읽기 → `CommandPlanPolicy`로 목표 결정 → AX 쓰기(`anchor`) → `CommandOutcomePolicy` 결정대로 Undo 기록·스냅 상태 커밋. `FrameApplyResult`를 `Result<CGRect, WindowCommandError>`로 매핑 |

## For AI Agents

### Working In This Directory
- `CommandPrimitives.swift`·`WindowCommand.swift`·`FrameCalculator.swift`·`FrameApply.swift`·`DisplayGeometry.swift`·`CommandOutcomePolicy.swift`·`CommandPlanPolicy.swift`·`WriteRetryPolicy.swift`·`ShortcutListPolicy.swift`·`CommandFeedbackPolicy.swift`는 **AppKit/AX import 금지**(순수 로직 유지, CoreGraphics는 허용). 단 그 이유는 "하네스가 깨져서"가 **아니다** — 하네스는 AppKit을 import하는 파일도 문제없이 컴파일한다(`Hotkeys/CarbonModifier.swift`가 실제로 그렇게 들어가 있다). 이 디렉터리에 거는 규칙은 **계층 규율**이다: 명령 모델·기하·정책은 UI를 몰라야 한다. 실행이 불가능해지는 진짜 경계는 `AXUIElement`를 운반하는 타입이다(`Tests/AGENTS.md` 참조).
- 새 명령 추가 시: `WindowCommand`에 케이스 + `displayName`, `FrameCalculator.targetFrame`에 분기, 필요하면 `menuCommands`와 `Hotkeys/HotkeyPreset` 바인딩에도 추가.
- 모든 frame은 **AX 좌표(좌상단 원점)** 기준. Cocoa 변환은 호출부(`WorkAreaResolver`)에서 처리됨.

### Testing Requirements
- `make test`(`Tests/CommandEngineTests*.swift`)가 절대 배치/축 합성/이동/상대 반분/상대 2/3/snapThrow 상태기계(스냅·던지기·제자리)·displayMove/여백 최대화·고정폭 판정/현재 화면 판정(면적·중심·displayID 동률)/인접 디스플레이 선택/AX 결과 커밋 정책/쓰기 재시도 판정/명령 모델(34개)/단축키 목록 표시 판정(검색·접힘)/실패 피드백 결정(비프·알림·권한 안내)/사용자 노출 문구 전수를 검증. 기하·정책 변경 시 해당 도메인 확장 파일에 케이스 추가. 순수 로직 라인 커버리지는 `make coverage`(≥90%)로 게이트.

### Common Patterns
- 이동 클램프: 창이 작업영역보다 크면(`upper < lower`) 좌상단(`lower`)에 고정.
- `WindowCommandExecutor`는 AX 적용 후 `CommandOutcomePolicy`의 결정에 따라 실제 변화가 확인되거나 가능성이 있을 때만 1단계 복원점을 기록한다. undo entry는 목표 frame 도달이 확인된 뒤에만 제거한다.

## Dependencies

### Internal
- `WindowAccess/FocusedWindowResolver`(창 해석), `WindowAccess/WindowFrameWriter`(AX 쓰기), `WindowAccess/WorkAreaResolver`(작업영역), `WindowAccess/WindowUndoStore`, `WindowAccess/FrontmostAppTracker`, `Shared/WindowCommandError`.

### External
- CoreGraphics(모델·계산), Cocoa(실행기).

<!-- MANUAL: -->
