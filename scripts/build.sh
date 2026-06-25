#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

xcodebuild \
    -project "$ROOT_DIR/Azimuth.xcodeproj" \
    -scheme Azimuth \
    -configuration Debug \
    -destination "platform=macOS" \
    CODE_SIGNING_ALLOWED=NO \
    build
