<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-07-23 -->

# Tests

## Purpose
명령 엔진 **순수 로직** 회귀 테스트. Xcode 테스트 타깃 대신 `swiftc`로 직접 컴파일/실행해 빠르고 의존성 없는 회귀 그물을 제공한다.

## Key Files
| File | Description |
|------|-------------|
| `CommandEngineTests.swift` | `@main` 실행형 테스트와 공용 `expect*` 헬퍼. 도메인별 테스트 함수를 호출하고 실패 시 비0 종료 |
| `CommandEngineTests+Frames.swift` | 절대 배치·축 독립 합성·이동·상대 축소·여백 최대화 등 frame 계산 테스트 |
| `CommandEngineTests+Displays.swift` | snap 판정·displayMove·인접 디스플레이 선택 테스트 |
| `CommandEngineTests+Apply.swift` | anchor·FrameApply·CommandOutcomePolicy 테스트. 부분 AX 적용·무시된 성공 쓰기·최종 read 실패의 상태 커밋을 값으로 검증 |
| `CommandEngineTests+Model.swift` | 명령 그룹·primitive 문자열·명령 모델·식별자·helpText 전수 테스트 |

## For AI Agents

### Working In This Directory
- 여기서 검증 가능한 건 **AppKit/AX에 의존하지 않는 순수 로직**뿐이다. `scripts/test.sh`와 `scripts/coverage.sh`가 `Commands`의 순수 소스 6개와 `CommandEngineTests*.swift` 5개를 직접 `swiftc`로 컴파일한다. 목록은 두 스크립트에 하드코딩되어 있으므로 순수 소스나 테스트 파일을 추가할 때 양쪽을 함께 갱신한다. 테스트 대상 소스에 AppKit/AX import를 추가하면 하네스가 깨진다.
- 기하/명령 변경 시 여기 케이스를 추가한다. 작업영역은 `CGRect(x:0,y:25,w:1920,h:1055)` 기준 픽스처.

### Testing Requirements
- 실행: `make test`(= `./scripts/test.sh`). CI의 "Command-engine tests" 스텝과 동일.
- 커버리지: `make coverage`(= `./scripts/coverage.sh`). **순수 로직 라인 커버리지 ≥ 90% 목표**(미만이면 비0 종료, `COVERAGE_MIN`로 조정). 신규·변경 로직은 케이스를 함께 추가해 이 선을 유지한다. AppKit/AX 계층은 측정 제외(라이브 검증).

### Common Patterns
- `expect(label, got, want)` 헬퍼 + `approx`(부동소수 0.001 허용)로 frame 비교. 통과 시 `PASS — all N checks`.

## Dependencies

### Internal
- `Azimuth/Commands/FrameCalculator.swift`, `FrameApply.swift`, `CommandPrimitives.swift`, `WindowCommand.swift`, `DisplayGeometry.swift`, `CommandOutcomePolicy.swift`(직접 컴파일 대상).

### External
- CoreGraphics, Foundation.

<!-- MANUAL: -->
