#!/bin/zsh

# 레거시 릴리스 게이트: Sparkle 실제 비교기로 `직전 레거시 < 후보 < live 본판`을 단언한다.
#
#   ./scripts/legacy-version-order.sh <후보 빌드 번호(209.N)> <Sparkle.framework가 든 디렉터리> <태그>
#
# - 후보 > 직전 레거시: 아니면 레거시 사용자에게 새 릴리스가 제안되지 않는다. 같음은 **같은 태그의 재실행**일 때만
#   허용한다(라이브 피드의 다운로드 주소가 이 태그를 가리킬 때). 다른 태그가 같은 번호를 쓰면 Sparkle이 새것으로
#   보지 않으므로 거부한다.
# - 후보 < 본판: 아니면 13+로 올라간 레거시 사용자가 본판으로 옮겨 가지 못한다.
# 두 피드 주소는 앱과 같은 출처(`Azimuth/Shared/UpdateFeed.swift`)에서 읽는다. 레거시 피드가 아직 없으면(첫 릴리스,
# HTTP 404) 직전 비교만 건너뛴다. 그 밖의 네트워크 오류는 실패로 본다.

set -euo pipefail

CANDIDATE="${1:?usage: legacy-version-order.sh <candidate build> <Sparkle framework dir> <tag>}"
SPARKLE_DIR="${2:?Sparkle framework directory required}"
TAG="${3:?release tag required}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

feed_url() { sed -nE "s/.*static let $1 = \"([^\"]+)\".*/\\1/p" "$ROOT_DIR/Azimuth/Shared/UpdateFeed.swift"; }
MAIN_FEED="$(feed_url mainURL)"
LEGACY_FEED="$(feed_url legacyURL)"
[[ -n "$MAIN_FEED" && -n "$LEGACY_FEED" ]] || { print -u2 "feed URLs not found in UpdateFeed.swift"; exit 1; }

# appcast의 가장 높은 항목 버전(<sparkle:version> 또는 enclosure의 sparkle:version 속성).
feed_version() {
    python3 - "$1" <<'PY'
import sys, xml.etree.ElementTree as ET
ns = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
versions = []
for item in ET.parse(sys.argv[1]).getroot().iter("item"):
    element = item.find(ns + "version")
    enclosure = item.find("enclosure")
    value = element.text if element is not None else (enclosure.get(ns + "version") if enclosure is not None else None)
    if value:
        versions.append(value.strip())
if not versions:
    sys.exit("no item version in appcast")
print("\n".join(versions))
PY
}

xcrun swiftc -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker "$SPARKLE_DIR" \
    "$ROOT_DIR/scripts/legacy-sparkle-compare.swift" -o "$WORK/compare"
compare() { "$WORK/compare" "$1" "$2"; }
# 여러 항목 중 Sparkle 기준으로 가장 높은 버전.
highest() {
    local best="" candidate
    for candidate in ${(f)"$(feed_version "$1")"}; do
        [[ -z "$best" || "$(compare "$candidate" "$best")" == 1 ]] && best="$candidate"
    done
    print "$best"
}

curl -fsSL "$MAIN_FEED" -o "$WORK/main.xml"
MAIN_VERSION="$(highest "$WORK/main.xml")"
[[ "$(compare "$CANDIDATE" "$MAIN_VERSION")" == -1 ]] \
    || { print -u2 "✗ candidate $CANDIDATE is not older than live main $MAIN_VERSION (13+ migration would stall)"; exit 1; }
print "  ok    candidate $CANDIDATE < live main $MAIN_VERSION"

code="$(curl -sSL -o "$WORK/legacy.xml" -w '%{http_code}' "$LEGACY_FEED")"
case "$code" in
    200)
        PREVIOUS="$(highest "$WORK/legacy.xml")"
        order="$(compare "$PREVIOUS" "$CANDIDATE")"
        if [[ "$order" == 0 ]]; then
            # 앞선 실행이 피드 갱신 뒤 실패해 같은 태그를 다시 돌리는 경우만 통과.
            grep -qF "/releases/download/$TAG/" "$WORK/legacy.xml" \
                || { print -u2 "✗ live legacy feed already serves $CANDIDATE from a different tag than $TAG"; exit 1; }
            print "  ok    previous legacy $PREVIOUS == candidate (re-run of $TAG)"
        elif [[ "$order" == -1 ]]; then
            print "  ok    previous legacy $PREVIOUS < candidate $CANDIDATE"
        else
            print -u2 "✗ previous legacy $PREVIOUS is newer than candidate $CANDIDATE"; exit 1
        fi
        ;;
    404) print "  ok    no legacy feed yet (first legacy release)" ;;
    *) print -u2 "✗ legacy feed fetch failed (HTTP $code)"; exit 1 ;;
esac
print "✓ version order holds"
