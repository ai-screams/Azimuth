#!/bin/zsh

# 레거시판: 완성된 Azimuth.app에 macOS 10.13용 Swift 런타임을 넣고 다시 서명한다.
#
#   ./scripts/legacy-bundle-runtime.sh <Azimuth.app> <signing identity>
#
# identity `-`는 ad-hoc 서명이다(브랜치 CI의 서명 없는 번들 게이트용, timestamp 없음). 배포는 Developer ID.
#
# 1. 표준 라이브러리(libswiftCore 등): 10.14.4 미만에는 OS Swift 런타임이 없다. Xcode가 대개 넣지만,
#    빠졌으면 툴체인 `swift-5.0/macosx`에서 `swift-stdlib-tool`로 채운다.
# 2. back-deploy 동시성 런타임(`swift-5.5/macosx/libswift_Concurrency.dylib`): Apple 공식 지원은 10.15+라
#    Xcode가 10.13 타깃에 넣어 주지 않는다. 기본 MainActor 격리 코드가 이 dylib를 weak로 참조하므로
#    없으면 순수 Swift 객체 해제 순간 종료된다(10.13 실기 확인). 여기서 직접 넣는다.
# 3. 넣은 dylib와 앱을 같은 정체성·hardened runtime·timestamp로 다시 서명한다(공증 전 단계에서 부른다).

set -euo pipefail

APP="${1:?usage: legacy-bundle-runtime.sh <Azimuth.app> <signing identity>}"
IDENTITY="${2:?signing identity required}"
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
# 앱은 export 때 붙은 entitlements·requirements를 그대로 두고 서명만 새로 한다.
"${SIGN[@]}" --preserve-metadata=entitlements,requirements "$APP"
codesign --verify --deep --strict "$APP"
print "✓ runtime bundled and signed"
