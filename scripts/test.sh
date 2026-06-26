#!/bin/zsh

# 명령 엔진 순수 로직 테스트를 swiftc로 컴파일/실행한다.
# Xcode 테스트 타깃 없이 회귀 그물을 제공한다.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BIN="$(mktemp -t yuri-tests-XXXXXX)"

swiftc \
    "$ROOT_DIR/Azimuth/Commands/FrameCalculator.swift" \
    "$ROOT_DIR/Azimuth/Commands/CommandPrimitives.swift" \
    "$ROOT_DIR/Azimuth/Commands/WindowCommand.swift" \
    "$ROOT_DIR/Tests/CommandEngineTests.swift" \
    -o "$BIN" || { rm -f "$BIN"; exit 1; }

"$BIN"
result=$?
rm -f "$BIN"
exit $result
