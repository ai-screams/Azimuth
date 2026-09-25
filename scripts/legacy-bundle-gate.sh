#!/bin/zsh

# 레거시판 번들 게이트: 완성된 Azimuth.app이 macOS 10.13에서 뜨고 동작하는 데 필요한 것을 단언한다.
#
#   ./scripts/legacy-bundle-gate.sh <Azimuth.app> [--signed]
#
# 서명 없는 검사(항상): 최소 OS 10.13, 아키텍처, rpath, 동봉 Swift 런타임과 back-deploy 동시성 런타임의
# 존재·참조, 비 weak Swift 심볼 누락 0. `--signed`(릴리스): 여기에 앱과 모든 동봉 dylib의 서명·hardened
# runtime·Developer ID 정체성을 더한다.
#
# 왜 존재를 따로 단언하나: 앱은 `libswift_Concurrency`를 weak로 링크한다. 그 dylib가 빠져도 앱은 뜨지만,
# 순수 Swift 객체가 해제되는 순간 `_$sScMMa`(MainActor 메타데이터)를 못 찾아 dyld가 앱을 끝낸다(10.13 실기).
# 비 weak 심볼 검사만으로는 이 누락을 못 잡는다.

set -euo pipefail

APP="${1:?usage: legacy-bundle-gate.sh <Azimuth.app> [--signed]}"
MODE="${2:-}"
# 모르는 인자는 거부한다: 오타(`--singed`)가 서명 검사를 건너뛴 채 통과하지 않게.
[[ $# -le 2 && ( -z "$MODE" || "$MODE" == --signed ) ]] \
    || { print -u2 "usage: legacy-bundle-gate.sh <Azimuth.app> [--signed]"; exit 2; }
EXPECT_AUTHORITY="${EXPECT_AUTHORITY:-Developer ID Application}"
EXPECT_TEAM="${EXPECT_TEAM:-7K6MK3KP9K}"

BIN="$APP/Contents/MacOS/Azimuth"
FW="$APP/Contents/Frameworks"
PLIST="$APP/Contents/Info.plist"
failures=0

pass() { print "  ok    $1"; }
fail() { print "  FAIL  $1"; failures=$((failures + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi }
# `lipo -verify_arch`는 도구 버전에 따라 아키텍처 여러 개를 받지 못한다 → `-archs` 출력으로 판정.
# 버전이 10.13.0 이하인가(숫자 단위 비교 — 문자열 접두어로는 10.13.1이 통과한다).
at_most_10_13() {
    [[ "$1" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]] || return 1
    local -a v=("${(@s:.:)1}")
    local major=$v[1] minor=$v[2] patch=${v[3]:-0}
    (( major < 10 || (major == 10 && minor < 13) || (major == 10 && minor == 13 && patch == 0) ))
}
# Mach-O 한 조각의 최소 OS(LC_VERSION_MIN_MACOSX의 version 또는 LC_BUILD_VERSION의 minos).
min_os() {
    otool -arch "$1" -l "$2" | grep -A3 -E "LC_VERSION_MIN_MACOSX|LC_BUILD_VERSION" \
        | awk '$1 == "version" || $1 == "minos" {print $2; exit}'
}
has_archs() { local file="$1" arch; shift; for arch; do [[ " $(lipo -archs "$file") " == *" $arch "* ]] || return 1; done }

print "▸ legacy bundle gate: $APP ${MODE:+($MODE)}"
[[ -x "$BIN" ]] || { print "  FAIL  executable missing: $BIN"; exit 1; }

# ── 최소 OS와 아키텍처 ─────────────────────────────────────────────────────────
check "LSMinimumSystemVersion = 10.13" \
    '[[ "$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$PLIST")" == 10.13 ]]'
archs="$(lipo -archs "$BIN")"
check "executable is universal x86_64 + arm64 (archs: $archs)" 'has_archs "$BIN" x86_64 arm64'
check "x86_64 minimum OS <= 10.13 ($(min_os x86_64 "$BIN"))" 'at_most_10_13 "$(min_os x86_64 "$BIN")"'
check "arm64 minimum OS is 11.0" 'otool -arch arm64 -l "$BIN" | grep -A4 LC_BUILD_VERSION | grep -q "minos 11.0"'
# 순서가 중요하다: OS 런타임(/usr/lib/swift)이 먼저여야 10.14.4+ 인텔 맥은 OS 것을 쓰고, 10.13에서만 동봉본으로
# 넘어온다. 반대면 OS 런타임과 동봉 5.0 런타임이 한 프로세스에 함께 실릴 수 있다.
for arch in x86_64 arm64; do
    check "$arch rpath is /usr/lib/swift then @executable_path/../Frameworks" \
        '[[ "$(otool -arch "$arch" -l "$BIN" | grep -A2 LC_RPATH | sed -nE "s/^ *path (.*) \(offset.*/\1/p" \
            | tr "\n" " ")" == "/usr/lib/swift @executable_path/../Frameworks " ]]'
done

# ── 동봉 런타임 ────────────────────────────────────────────────────────────────
check "bundles libswiftCore.dylib (10.13 has no OS Swift runtime)" '[[ -f "$FW/libswiftCore.dylib" ]]'
check "bundles libswift_Concurrency.dylib" '[[ -f "$FW/libswift_Concurrency.dylib" ]]'
for arch in x86_64 arm64; do
    check "$arch executable references @rpath/libswift_Concurrency.dylib" \
        'otool -arch "$arch" -L "$BIN" | grep -q "@rpath/libswift_Concurrency.dylib"'
done
if [[ -f "$FW/libswift_Concurrency.dylib" ]]; then
    # arm64도 필요하다: Apple Silicon의 macOS 11에는 OS 동시성 런타임이 없어(12부터) 동봉본으로 넘어온다.
    check "libswift_Concurrency has x86_64 and arm64" \
        'has_archs "$FW/libswift_Concurrency.dylib" x86_64 arm64'
fi
# 동봉 런타임은 10.13에서 실려야 한다: x86_64 조각의 최소 OS가 10.13 이하인지(릴리스는 Xcode 26.3 툴체인의 것을 넣는다).
for dylib in "$FW"/libswift*.dylib(N); do
    check "${dylib:t} x86_64 minimum OS <= 10.13" 'at_most_10_13 "$(min_os x86_64 "$dylib")"'
done
check "Sparkle.framework has x86_64 and arm64" \
    'has_archs "$FW/Sparkle.framework/Versions/B/Sparkle" x86_64 arm64'

# 비 weak Swift 심볼: 아키텍처마다, 이미지가 `@rpath`로 싣는(= 번들이 대야 하는) Swift 라이브러리의 심볼이
# 모두 동봉본의 같은 아키텍처 조각에 있어야 한다. x86_64(10.13)는 표준 라이브러리 전부가 `@rpath`, arm64(11+)는
# OS의 /usr/lib/swift를 쓰고 `libswift_Concurrency`만 `@rpath`(11에는 OS 동시성 런타임이 없다).
# 라이브러리 이름을 정확히 맞춘다("from libswiftCore"가 libswiftCoreGraphics까지 잡지 않게).
# 내보내는 심볼 목록을 파일로 만들어 `comm`으로 비교한다(`grep -q` 파이프는 pipefail에서 SIGPIPE로 거짓 실패한다).
SYMS_DIR="$(mktemp -d)"
trap 'rm -rf "$SYMS_DIR"' EXIT
missing=0
for arch in x86_64 arm64; do
    for image in "$BIN" "$FW"/libswift*.dylib(N); do
        has_archs "$image" "$arch" || continue
        bundled=(${(f)"$(otool -arch "$arch" -L "$image" \
            | sed -nE 's#^[[:space:]]*@rpath/(libswift[A-Za-z_]+)\.dylib .*#\1#p' | sort -u)"})
        nm -arch "$arch" -m "$image" 2>/dev/null | grep "(undefined) external" | grep -v weak \
            | sed -nE 's/.*external ([^ ]+) \(from (libswift[A-Za-z_]+)\)$/\2 \1/p' >"$SYMS_DIR/needs" || true
        for lib in ${(f)"$(cut -d' ' -f1 "$SYMS_DIR/needs" | sort -u)"}; do
            (( ${bundled[(Ie)$lib]} )) || continue # OS가 대는 라이브러리
            target="$FW/$lib.dylib"
            if [[ ! -f "$target" ]] || ! has_archs "$target" "$arch"; then
                print "        missing $arch library $lib (needed by ${image:t})"
                missing=$((missing + 1))
                continue
            fi
            exports="$SYMS_DIR/$arch-$lib.exports"
            [[ -f "$exports" ]] || nm -arch "$arch" -gUj "$target" 2>/dev/null | sort -u >"$exports"
            awk -v l="$lib" '$1 == l {print $2}' "$SYMS_DIR/needs" | sort -u >"$SYMS_DIR/wanted"
            for sym in ${(f)"$(comm -23 "$SYMS_DIR/wanted" "$exports")"}; do
                print "        $arch $lib lacks $sym (needed by ${image:t})"
                missing=$((missing + 1))
            done
        done
    done
done
check "required Swift symbols resolvable in bundled runtime ($missing missing)" '[[ $missing == 0 ]]'

# ── 서명(릴리스) ──────────────────────────────────────────────────────────────
if [[ "$MODE" == "--signed" ]]; then
    # 레거시 빌드 번호 `209.N`(`release.sh`의 LEGACY_BUILD_MAJOR, 앱의 `VersionDisplay.legacyBuildMajor`).
    # 릴리스·시험 앱만 이 번호를 받는다 — 브랜치 CI 빌드는 프로젝트 기본 번호라 서명 모드에서만 본다.
    check "CFBundleVersion is 209.N" \
        '[[ "$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")" =~ "^209\.[0-9]+$" ]]'
    check "codesign --verify --deep --strict" 'codesign --verify --deep --strict "$APP" 2>/dev/null'
    sign_info="$(codesign -dvvv "$APP" 2>&1)"
    check "app signed by $EXPECT_AUTHORITY" '[[ "$sign_info" == *"Authority=$EXPECT_AUTHORITY"* ]]'
    check "app TeamIdentifier $EXPECT_TEAM" '[[ "$sign_info" == *"TeamIdentifier=$EXPECT_TEAM"* ]]'
    check "app hardened runtime" '[[ "$sign_info" =~ "flags=.*runtime" ]]'
    for dylib in "$FW"/*.dylib(N); do
        dylib_info="$(codesign -dvvv "$dylib" 2>&1)"
        check "${dylib:t} signed ($EXPECT_AUTHORITY, runtime)" \
            'codesign --verify --strict "$dylib" 2>/dev/null && [[ "$dylib_info" == *"Authority=$EXPECT_AUTHORITY"* && "$dylib_info" =~ "flags=.*runtime" ]]'
    done
fi

if [[ $failures -gt 0 ]]; then
    print "✗ legacy bundle gate: $failures failure(s)"
    exit 1
fi
print "✓ legacy bundle gate passed"
