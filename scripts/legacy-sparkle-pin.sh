#!/bin/zsh

# 레거시판 Sparkle 고정 단언: 프로젝트가 2.9.3 exact를 요구하고, Package.resolved가 그 정확한 커밋을 가리킨다.
# 2.10+는 macOS 12가 필요해 10.13~11에서 앱이 뜨지 않는다 — 의존성 갱신(수동·봇)이 조용히 올리지 못하게 막는다.
# CI(`ci.yml`)와 릴리스(`release-legacy.yml`)가 부른다.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$ROOT_DIR/Azimuth.xcodeproj/project.pbxproj"
RESOLVED="$ROOT_DIR/Azimuth.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
EXPECT_VERSION="2.9.3"
EXPECT_REVISION="d46d456107feacc80711b21847b82b07bd9fb46e"

grep -A3 'XCRemoteSwiftPackageReference "Sparkle"' "$PBXPROJ" >/dev/null \
    || { print -u2 "✗ Sparkle package reference not found"; exit 1; }
requirement="$(sed -n '/XCRemoteSwiftPackageReference "Sparkle"/,/};/p' "$PBXPROJ" | sed -n '/requirement = {/,/};/p')"
[[ "$requirement" == *"kind = exactVersion;"* && "$requirement" == *"version = $EXPECT_VERSION;"* ]] \
    || { print -u2 "✗ project must require Sparkle exactVersion $EXPECT_VERSION"; print -u2 "$requirement"; exit 1; }

python3 - "$RESOLVED" "$EXPECT_VERSION" "$EXPECT_REVISION" <<'PY'
import json, sys
path, version, revision = sys.argv[1:]
pins = {pin["identity"]: pin["state"] for pin in json.load(open(path))["pins"]}
state = pins.get("sparkle")
if state != {"revision": revision, "version": version}:
    sys.exit(f"✗ Package.resolved sparkle is {state}, expected {version} @ {revision}")
PY
print "✓ Sparkle pinned: $EXPECT_VERSION exact @ ${EXPECT_REVISION[1,12]}"
