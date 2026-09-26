#!/bin/bash

# 출시 본문 자동 목록("What's Changed")의 비교 기준을 고른다 — 이번 태그 바로 앞의 정식 출시.
# 지정하지 않으면 GitHub이 스스로 고르는데, 본판·레거시판·피드 전용 릴리스(`legacy-feed`)가 한 저장소에 섞여
# 엉뚱한 기준을 잡는다(Legacy 3의 목록이 `legacy-feed...legacy-v1.7.2-3`으로 나왔다).
#
#   <게시된 릴리스 태그, 한 줄에 하나> | ./scripts/previous-release-tag.sh <이번 태그>
#
# - 본판 `vX.Y.Z[-접미사]`: 정식 `vA.B.C` 가운데 X.Y.Z보다 작은 것의 최댓값.
# - 레거시판 `legacy-vX.Y.Z-N`: `legacy-v…-M` 가운데 M < N의 최댓값(N은 채널 전체 일련번호). 채널의 첫 출시면
#   갈라져 나온 본판(`vA.B.C` ≤ X.Y.Z의 최댓값).
# 목록이 비었으면(저장소의 첫 출시) 빈 줄을 내고, 액션은 GitHub의 자동 선택으로 돌아간다. 그 밖에 고를 수 없으면
# (모르는 태그 형식, 기준 없음, 버전 한 자리가 9자리 초과) 실패한다 — 자동 선택으로 돌아가면 다시 엉뚱한 기준이 된다.
# 본판과 `legacy/10.13`에 같은 파일을 둔다(CI가 대조). macOS(release.yml)와 ubuntu(release-legacy.yml publish)
# 양쪽에서 돌므로 bash와 POSIX awk만 쓴다(mawk는 `{m,n}` 반복을 모를 수 있어 길이는 `length`로 잰다).

set -euo pipefail

CURRENT="${1:?usage: previous-release-tag.sh <tag>  (published tag names on stdin)}"

awk -v cur="$CURRENT" '
function fits(a, b, c) { return length(a) <= 9 && length(b) <= 9 && length(c) <= 9 }
function key(a, b, c) { return sprintf("%09d%09d%09d", a, b, c) }
BEGIN {
    mode = "none"
    if (cur ~ /^legacy-v[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$/) {
        mode = "legacy"; n = cur; sub(/.*-/, "", n); limit = n + 0
        split(substr(cur, 9), p, /[.-]/)
    } else if (cur ~ /^v[0-9]+\.[0-9]+\.[0-9]+(-.+)?$/) {
        mode = "main"; split(substr(cur, 2), p, /[.-]/)
    }
    if (mode != "none" && fits(p[1], p[2], p[3])) base = key(p[1], p[2], p[3])
    else mode = "none"
}
mode == "legacy" && /^legacy-v[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$/ {
    split(substr($0, 9), r, /[.-]/)
    if (!fits(r[1], r[2], r[3])) next
    m = $0; sub(/.*-/, "", m); m += 0
    if (m < limit && (tag == "" || m > best)) { best = m; tag = $0 }
}
/^v[0-9]+\.[0-9]+\.[0-9]+$/ {
    split(substr($0, 2), q, ".")
    if (!fits(q[1], q[2], q[3])) next
    k = key(q[1], q[2], q[3])
    # 본판은 이번 버전보다 작은 것, 레거시판의 첫 출시 대비책은 같은 버전까지.
    if ((mode == "main" && k < base) || (mode == "legacy" && k <= base)) {
        if (fallback == "" || k > fbest) { fbest = k; fallback = $0 }
    }
}
END {
    if (mode == "none") { print "previous-release-tag: unsupported tag " cur > "/dev/stderr"; exit 2 }
    if (mode == "legacy" && tag != "") { print tag; exit 0 }
    if (fallback != "") { print fallback; exit 0 }
    if (NR == 0) { print ""; exit 0 }
    print "previous-release-tag: no compare base for " cur > "/dev/stderr"
    exit 2
}
'
