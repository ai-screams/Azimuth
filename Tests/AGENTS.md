<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-29 -->

# Tests

## Purpose
명령 엔진 **순수 로직** 회귀 테스트. Xcode 테스트 타깃 대신 `swiftc`로 직접 컴파일/실행해 빠르고 의존성 없는 회귀 그물을 제공한다.

## Key Files
| File | Description |
|------|-------------|
| `CommandEngineTests.swift` | `@main` 실행형 테스트. `FrameCalculator`(기하)와 `WindowCommand`(모델)만 검증: 절대 배치/축 독립 합성/이동(클램프)/상대 반분/상대 2/3(relativeTwoThird)/shrink 하한/snapHalves·isSnapped/displayMove/anchorOrigin/명령 모델(33개)·식별자 전수. 실패 시 비0 종료. AppKit/AX 비의존 |

## For AI Agents

### Working In This Directory
- 여기서 검증 가능한 건 **AppKit/AX에 의존하지 않는 순수 로직**뿐이다. `scripts/test.sh`가 `Commands/FrameCalculator.swift` + `Commands/CommandPrimitives.swift` + `Commands/WindowCommand.swift` + 이 파일만 `swiftc`로 컴파일하므로, 테스트가 import하는 소스에 AppKit/AX import를 추가하면 빌드가 깨진다.
- 기하/명령 변경 시 여기 케이스를 추가한다. 작업영역은 `CGRect(x:0,y:25,w:1920,h:1055)` 기준 픽스처.

### Testing Requirements
- 실행: `make test`(= `./scripts/test.sh`). CI의 "Command-engine tests" 스텝과 동일.
- 커버리지: `make coverage`(= `./scripts/coverage.sh`). **순수 로직 라인 커버리지 ≥ 90% 목표**(미만이면 비0 종료, `COVERAGE_MIN`로 조정). 신규·변경 로직은 케이스를 함께 추가해 이 선을 유지한다. AppKit/AX 계층은 측정 제외(라이브 검증).

### Common Patterns
- `expect(label, got, want)` 헬퍼 + `approx`(부동소수 0.001 허용)로 frame 비교. 통과 시 `PASS — all N checks`.

## Dependencies

### Internal
- `Azimuth/Commands/FrameCalculator.swift`, `Azimuth/Commands/CommandPrimitives.swift`, `Azimuth/Commands/WindowCommand.swift`(직접 컴파일 대상).

### External
- CoreGraphics, Foundation.

<!-- MANUAL: -->
