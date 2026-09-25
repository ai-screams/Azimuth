# 하네스가 컴파일하는 파일의 단일 출처. test.sh 와 coverage.sh 가 이 파일을 source 한다.
#
# 따로 들고 있으면 한쪽에만 추가했을 때 `make test` 는 통과하는데 CI 가 도는 `make coverage` 의
# 분모에서만 빠진다 — 새 파일이 측정되지 않은 채 게이트를 통과한다.
#
# ⚠️ 이 파일에 `set` 줄을 넣지 말 것. `source` 는 호출자 셸에서 실행되므로 `set -euo pipefail` 을
# 습관적으로 붙이면 `-e` 가 두 스크립트에 주입된다. test.sh 는 종료코드를 보존하려고 의도적으로
# `-uo` 만 쓴다(scripts/AGENTS.md). 배열 정의만 둔다.
#
# 경로는 리포 루트 기준 상대 경로다(두 스크립트 모두 루트로 cd 한 뒤 쓴다).

# 커버리지 측정 대상 프로덕션 소스. AppKit import 자체는 문제가 아니다 —
# 넣을 수 없는 것은 AXUIElement 를 운반해 값으로 만들 수 없는 타입이다.
HARNESS_SRC=(
    "Azimuth/Commands/FrameCalculator.swift"
    "Azimuth/Commands/FrameApply.swift"
    "Azimuth/Commands/CommandPrimitives.swift"
    "Azimuth/Commands/WindowCommand.swift"
    "Azimuth/Commands/DisplayGeometry.swift"
    "Azimuth/Commands/CommandOutcomePolicy.swift"
    "Azimuth/Commands/CommandPlanPolicy.swift"
    "Azimuth/Commands/WriteRetryPolicy.swift"
    "Azimuth/Commands/ShortcutListPolicy.swift"
    "Azimuth/Commands/ShortcutRowPolicy.swift"
    "Azimuth/Commands/CommandFeedbackPolicy.swift"
    "Azimuth/Shared/AXMessagingTimeout.swift"
    "Azimuth/Shared/WindowFrame.swift"
    "Azimuth/Shared/WindowCommandError.swift"
    "Azimuth/Hotkeys/CarbonModifier.swift"
    "Azimuth/Hotkeys/HotkeyShortcut.swift"
    "Azimuth/Hotkeys/HotkeyPreset.swift"
    "Azimuth/Hotkeys/BindingResolver.swift"
    "Azimuth/Shared/Log.swift"
)

# 테스트 파일. 함께 컴파일하되 커버리지 분모에는 넣지 않는다.
HARNESS_TESTS=(
    "Tests/CommandEngineTests.swift"
    "Tests/CommandEngineTests+Frames.swift"
    "Tests/CommandEngineTests+Displays.swift"
    "Tests/CommandEngineTests+Plan.swift"
    "Tests/CommandEngineTests+Apply.swift"
    "Tests/CommandEngineTests+Model.swift"
    "Tests/CommandEngineTests+Hotkeys.swift"
    "Tests/CommandEngineTests+Legacy.swift"
)
