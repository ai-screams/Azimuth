#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftformat >/dev/null 2>&1; then
    echo "error: SwiftFormat is not installed." >&2
    echo "hint: brew install swiftformat" >&2
    exit 1
fi

swiftformat "$ROOT_DIR/Azimuth" --config "$ROOT_DIR/.swiftformat"
