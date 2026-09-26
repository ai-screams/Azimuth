#!/bin/zsh

# 업데이트 창 버전 표기 어댑터(`UpdateVersionDisplayer`)가 Sparkle이 찾는 ObjC 이름에 응답하는지 확인한다.
# 순수 하네스(`make test`)는 Sparkle을 링크하지 않으므로 따로 둔다. `make sparkle-adapter-check`, CI에서 부른다.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if ! xcodebuild -resolvePackageDependencies -project Azimuth.xcodeproj -scheme Azimuth \
    -derivedDataPath "$WORK_DIR/dd" >"$WORK_DIR/resolve.log" 2>&1; then
    cat "$WORK_DIR/resolve.log" >&2 # 임시 폴더는 곧 지워지므로 원인을 먼저 남긴다
    exit 1
fi
XCF="$(find "$WORK_DIR/dd/SourcePackages/artifacts" -maxdepth 4 -name Sparkle.xcframework | head -1)"
SLICE="$XCF/macos-arm64_x86_64"
[[ -d "$SLICE" ]] || { print -u2 "Sparkle xcframework not found"; exit 1; }

xcrun swiftc -F "$SLICE" -framework Sparkle -Xlinker -rpath -Xlinker "$SLICE" \
    -swift-version 5 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault \
    Azimuth/Shared/UpdateVersionText.swift Azimuth/UpdateVersionDisplayer.swift \
    scripts/sparkle-adapter-check/main.swift -o "$WORK_DIR/check"
"$WORK_DIR/check"
