#!/bin/zsh

# 순수 로직(명령 엔진) 코드 커버리지. test.sh와 동일한 파일을 LLVM source-based 계측으로
# 빌드·실행해 llvm-cov로 측정한다. 목표: 라인 커버리지 ≥ 90%(COVERAGE_MIN로 조정 가능).
# AppKit/AX 계층은 단위테스트 대상이 아니므로(라이브 검증) 측정에서 제외한다.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

THRESHOLD=${COVERAGE_MIN:-90}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SRC=(
    "Azimuth/Commands/FrameCalculator.swift"
    "Azimuth/Commands/FrameApply.swift"
    "Azimuth/Commands/CommandPrimitives.swift"
    "Azimuth/Commands/WindowCommand.swift"
    "Azimuth/Commands/DisplayGeometry.swift"
    "Azimuth/Commands/CommandOutcomePolicy.swift"
)

swiftc -profile-generate -profile-coverage-mapping "${SRC[@]}" "Tests/CommandEngineTests.swift" "Tests/CommandEngineTests+Frames.swift" "Tests/CommandEngineTests+Displays.swift" "Tests/CommandEngineTests+Apply.swift" "Tests/CommandEngineTests+Model.swift" \
    -o "$TMP/tests" || { echo "build failed"; exit 1; }

LLVM_PROFILE_FILE="$TMP/tests.profraw" "$TMP/tests" >/dev/null || { echo "tests failed"; exit 1; }
xcrun llvm-profdata merge -sparse "$TMP/tests.profraw" -o "$TMP/tests.profdata"

xcrun llvm-cov report "$TMP/tests" -instr-profile="$TMP/tests.profdata" "${SRC[@]}"

total=$(xcrun llvm-cov export "$TMP/tests" -instr-profile="$TMP/tests.profdata" "${SRC[@]}" --summary-only \
    | /usr/bin/python3 -c 'import sys, json; print(round(json.load(sys.stdin)["data"][0]["totals"]["lines"]["percent"], 2))')

echo ""
echo "TOTAL line coverage: ${total}%  (minimum ${THRESHOLD}%)"
awk -v t="$total" -v m="$THRESHOLD" 'BEGIN { exit (t + 0 < m + 0) ? 1 : 0 }' \
    && { echo "PASS"; exit 0; } || { echo "FAIL — below ${THRESHOLD}% threshold"; exit 1; }
