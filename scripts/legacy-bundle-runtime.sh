#!/bin/zsh

# 레거시판: 완성된 Azimuth.app에 macOS 10.13용 Swift 런타임을 넣고 다시 서명한다.
#
#   ./scripts/legacy-bundle-runtime.sh <Azimuth.app> <signing identity> [--resign-sparkle]
#
# identity `-`는 ad-hoc 서명이다(브랜치 CI의 서명 없는 번들 게이트용, timestamp 없음). 배포는 Developer ID.
#
# Sparkle.framework 재서명: identity가 `-`이거나 `--resign-sparkle`을 줄 때만 안쪽부터 다시 서명한다(환경변수가
# 아니라 인자인 이유: 셸에 남은 값이 릴리스로 새어 들어가 깨진 봉인을 덮지 않게).
# - CI(`CODE_SIGNING_ALLOWED=NO`)는 Xcode가 Sparkle을 복사하며 봉인을 깨고 다시 서명하지 않는다 → ad-hoc으로 복구.
# - `legacy-build-app.sh`는 xcframework에서 그대로 복사하므로 자기 정체성으로 서명해야 한다(`--resign-sparkle`).
# - 릴리스(export)는 Xcode가 이미 Developer ID로 서명한다. 거기서 봉인이 깨져 있으면 덮지 않고 검증에서 실패한다.
#
# 1. 표준 라이브러리(libswiftCore 등): 10.14.4 미만에는 OS Swift 런타임이 없다. Xcode 빌드는 넣지만(26.3 CI 확인),
#    swiftc 직접 빌드(`legacy-build-app.sh`)에는 없으므로 툴체인 `swift-5.0/macosx`에서 `swift-stdlib-tool`로 채운다.
# 2. back-deploy 동시성 런타임(`swift-5.5/macosx/libswift_Concurrency.dylib`): 기본 MainActor 격리 코드가 이
#    dylib를 weak로 참조하므로 없으면 10.13에서 순수 Swift 객체 해제 순간 종료된다(실기 확인). Xcode 26.3 빌드는
#    넣지만 swiftc 직접 빌드에는 없다 — 없을 때만 넣는다. 어느 쪽이든 게이트가 존재·아키텍처·최소 OS를 단언한다.
# 3. 넣은 dylib와 앱을 같은 정체성·hardened runtime·timestamp로 다시 서명한다(공증 전 단계에서 부른다).

set -euo pipefail

APP="${1:?usage: legacy-bundle-runtime.sh <Azimuth.app> <signing identity> [--resign-sparkle]}"
IDENTITY="${2:?signing identity required}"
[[ $# -le 3 && ( -z "${3:-}" || "${3:-}" == --resign-sparkle ) ]] \
    || { print -u2 "usage: legacy-bundle-runtime.sh <Azimuth.app> <signing identity> [--resign-sparkle]"; exit 2; }
RESIGN_SPARKLE=0
[[ "$IDENTITY" == - || "${3:-}" == --resign-sparkle ]] && RESIGN_SPARKLE=1
FW="$APP/Contents/Frameworks"
TOOLCHAIN_LIB="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"
CONCURRENCY="$TOOLCHAIN_LIB/swift-5.5/macosx/libswift_Concurrency.dylib"

[[ -d "$APP" ]] || { print "no app at $APP" >&2; exit 1; }
[[ -f "$CONCURRENCY" ]] || { print "toolchain lacks $CONCURRENCY" >&2; exit 1; }
mkdir -p "$FW"

if [[ ! -f "$FW/libswiftCore.dylib" ]]; then
    print "▸ adding Swift standard libraries (swift-5.0)"
    xcrun swift-stdlib-tool --copy --platform macosx --scan-executable "$APP/Contents/MacOS/Azimuth" \
        --scan-folder "$FW" --destination "$FW" --source-libraries "$TOOLCHAIN_LIB/swift-5.0/macosx"
fi

if [[ ! -f "$FW/libswift_Concurrency.dylib" ]]; then
    print "▸ adding back-deployed libswift_Concurrency (swift-5.5)"
    cp -f "$CONCURRENCY" "$FW/"
fi

print "▸ re-signing bundled runtime and app ($IDENTITY)"
SIGN=(codesign --force --sign "$IDENTITY" --options runtime)
[[ "$IDENTITY" == - ]] || SIGN+=(--timestamp)
for dylib in "$FW"/libswift*.dylib(N); do
    "${SIGN[@]}" "$dylib"
done
SPARKLE="$FW/Sparkle.framework"
if [[ -d "$SPARKLE" && $RESIGN_SPARKLE == 1 ]]; then
    # 안쪽부터: XPC 서비스 → Autoupdate → Updater.app → 프레임워크.
    for component in "$SPARKLE"/Versions/B/XPCServices/*.xpc(N) "$SPARKLE/Versions/B/Autoupdate" \
        "$SPARKLE/Versions/B/Updater.app" "$SPARKLE"; do
        "${SIGN[@]}" "$component"
    done
fi
# 앱은 export 때 붙은 entitlements·requirements를 그대로 두고 서명만 새로 한다.
"${SIGN[@]}" --preserve-metadata=entitlements,requirements "$APP"
codesign --verify --deep --strict "$APP"
print "✓ runtime bundled and signed"
