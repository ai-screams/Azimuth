#!/bin/zsh

# 명령 엔진 순수 로직 테스트를 swiftc로 컴파일/실행한다.
# Xcode 테스트 타깃 없이 회귀 그물을 제공한다.
# 컴파일 대상 목록은 scripts/harness-sources.sh 가 단일 출처다.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/harness-sources.sh"

BIN="$(mktemp -t yuri-tests-XXXXXX)"

swiftc "${HARNESS_SRC[@]}" "${HARNESS_TESTS[@]}" \
    -o "$BIN" || { rm -f "$BIN"; exit 1; }

"$BIN"
result=$?
rm -f "$BIN"
exit $result
