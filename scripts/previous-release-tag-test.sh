#!/bin/bash

# `previous-release-tag.sh`의 선택 규칙을 고정한다(네트워크 없음, 태그 목록은 아래 고정값). CI에서 부른다.

set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/previous-release-tag.sh"
TAGS='legacy-v1.7.2-3
legacy-feed
legacy-v1.7.2-1
v1.7.2
v1.7.1
v1.10.0-rc1
v1.9.0
v1.7.0'
failures=0

# expect <이번 태그> <기대 출력 | FAIL> [태그 목록]
expect() {
    local got code=0
    got="$(printf '%s' "${3-$TAGS}" | "$SCRIPT" "$1" 2>/dev/null)" || code=$?
    if [[ "$2" == FAIL ]]; then
        ((code != 0)) && { echo "ok   $1 -> fails"; return; }
    elif ((code == 0)) && [[ "$got" == "$2" ]]; then
        echo "ok   $1 -> '${got}'"
        return
    fi
    echo "FAIL $1 -> '${got}' (exit ${code}, want '$2')"
    failures=$((failures + 1))
}

expect v1.7.3 v1.7.2              # 레거시·피드 릴리스가 더 최근이어도 본판끼리 비교
expect v1.7.2 v1.7.1              # 자기 자신(재실행)은 제외
expect v1.8.0-rc1 v1.7.2          # 시험판은 직전 정식 출시와 비교, 시험판끼리는 기준이 되지 않음
expect v1.10.0 v1.9.0             # 자리는 숫자로 비교(문자열이면 1.9 > 1.10)
expect legacy-v1.7.2-3 legacy-v1.7.2-1   # 게시되지 않은 번호(2)는 건너뜀, legacy-feed는 무시
expect legacy-v1.7.3-4 legacy-v1.7.2-3
expect legacy-v1.7.2-1 v1.7.2     # 채널의 첫 출시: 갈라져 나온 본판
expect legacy-v1.7.2-1 v1.7.1 $'v1.7.1\nlegacy-feed\nv1.8.0'   # 같은 버전 본판이 없으면 그 아래
expect v1.7.0 FAIL                # 목록은 있는데 기준이 없음: 자동 선택으로 돌아가지 않는다
expect legacy-rc-v1.7.2-3 FAIL    # 시험판 태그는 게시하지 않으므로 대상 아님
expect nonsense FAIL
expect v1000000000.0.0 FAIL       # 한 자리 9자리 초과는 비교 키가 깨진다
expect v1000000000.0.0 FAIL $'v999999999.0.0\nv2.0.0'
expect v3.0.0 v2.0.0 $'v1000000000.0.0\nv2.0.0'   # 목록 쪽의 초과 자리는 건너뜀
expect legacy-v1.7.2-3 legacy-v1.7.2-1 $'legacy-v1000000000.0.0-2\nlegacy-v1.7.2-1'   # 레거시 후보도 초과 자리는 건너뜀
expect v1.7.3 '' ''               # 저장소의 첫 출시: 빈 값(GitHub 자동 선택)
expect v1000000000.0.0 FAIL ''    # 목록이 비어도 이번 태그가 규칙 밖이면 실패

((failures == 0)) || { echo "previous-release-tag: ${failures} failure(s)"; exit 1; }
echo "previous-release-tag: all checks passed"
