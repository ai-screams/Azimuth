#!/bin/zsh

# 레거시판(macOS 10.13~12) 로컬 컴파일 검사.
#
# Xcode 27은 deployment target 12.0 미만을 거부하므로 이 브랜치에서는 `make build`가 실패한다.
# 레거시 릴리스는 CI의 Xcode 26.3이 빌드한다. 로컬에서는 이 스크립트로 Swift 컴파일러를 직접 불러
#   1. 모든 소스를 x86_64 macOS 10.13, arm64 macOS 11 기준으로 파일별 타입 검사하고
#   2. x86_64 10.13 실행 파일을 링크해 본다.
# 파일별(`-primary-file`) 검사를 쓰는 이유: 전체 모듈 검사는 첫 오류 파일에서 멈춰 나머지를 가린다.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

WORK_DIR="${LEGACY_CHECK_DIR:-$(mktemp -d)}"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
FRONTEND="$(xcrun -f swift-frontend)"

# Sparkle 바이너리 아티팩트(2.9.3 xcframework)를 받는다. 해석만 하므로 Xcode 27로도 된다.
xcodebuild -resolvePackageDependencies -project Azimuth.xcodeproj -scheme Azimuth \
    -derivedDataPath "$WORK_DIR/dd" >"$WORK_DIR/resolve.log" 2>&1
SPARKLE_DIR="$(find "$WORK_DIR/dd/SourcePackages/artifacts" -name Sparkle.xcframework -maxdepth 4 | head -1)"
SPARKLE_SLICE="$SPARKLE_DIR/macos-arm64_x86_64"
[[ -d "$SPARKLE_SLICE" ]] || { echo "Sparkle xcframework not found" >&2; exit 1; }

# 프로젝트 빌드 설정과 같은 언어 설정.
SWIFT_FLAGS=(
    -sdk "$SDK" -swift-version 5 -module-name Azimuth -default-isolation MainActor
    -enable-upcoming-feature DisableOutwardActorInference
    -enable-upcoming-feature GlobalActorIsolatedTypesUsability
    -enable-upcoming-feature InferIsolatedConformances
    -enable-upcoming-feature InferSendableFromCaptures
    -enable-upcoming-feature MemberImportVisibility
    -enable-upcoming-feature NonisolatedNonsendingByDefault
    -F "$SPARKLE_SLICE"
)

FILES=(${(f)"$(find Azimuth -name '*.swift' | sort)"})
status_code=0

for target in x86_64-apple-macosx10.13 arm64-apple-macos11; do
    log="$WORK_DIR/typecheck-$target.log"
    : >"$log"
    failed_files=0
    for file in $FILES; do
        others=(${FILES:#$file})
        # 진단 문구에 기대지 않는다: 컴파일러 비정상 종료나 " error:" 없는 치명 오류도 실패로 센다.
        if ! "$FRONTEND" -typecheck -primary-file "$file" $others -target "$target" "${SWIFT_FLAGS[@]}" \
            >>"$log" 2>&1; then
            echo "$file: frontend exited nonzero" >>"$log"
            failed_files=$((failed_files + 1))
        fi
    done
    errors=$(grep -c ' error:' "$log" || true)
    echo "typecheck $target: $errors error(s), $failed_files file(s) failed"
    if [[ "$errors" != "0" || "$failed_files" != "0" ]]; then
        grep ' error:' "$log" | sort -u | head -20 || true
        grep 'frontend exited nonzero' "$log" | head -20 || true
        status_code=1
    fi
done

xcrun swiftc -O -target x86_64-apple-macosx10.13 "${SWIFT_FLAGS[@]}" -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks $FILES -o "$WORK_DIR/Azimuth" \
    >"$WORK_DIR/link.log" 2>&1 || { echo "link x86_64 10.13: FAILED"; grep ' error:' "$WORK_DIR/link.log" | head; exit 1; }
echo "link x86_64 10.13: ok ($(otool -l "$WORK_DIR/Azimuth" | grep -A2 LC_VERSION_MIN_MACOSX | awk '/version/ {print $2}'))"

exit $status_code
