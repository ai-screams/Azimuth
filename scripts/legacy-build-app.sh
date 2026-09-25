#!/bin/zsh

# 레거시판 로컬 시험 빌드: 실기(macOS 10.13 등)에 옮겨 돌려 볼 서명된 Azimuth.app을 만든다.
#
# Xcode 27은 10.13 타깃을 거부해 `xcodebuild`로 만들 수 없다. 그래서 Swift 컴파일러로 직접 컴파일·링크하고
# 번들을 조립한다. 배포판은 CI(Xcode 26.3, `release.sh`)가 만든다 — 이 빌드는 실기 확인용이다.
#
#   SIGN_IDENTITY="Developer ID Application: …" BUNDLE_ID=com.aiscream.Azimuth.legacytest ./scripts/legacy-build-app.sh
#
# 산출물: build/legacy/Azimuth.app (x86_64 + arm64, 최소 10.13 / 11.0). 끝에 번들 게이트를 서명 모드로 돈다.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
BUNDLE_ID="${BUNDLE_ID:-com.aiscream.Azimuth.legacytest}"
MARKETING_VERSION="${MARKETING_VERSION:-1.7.2}"
BUILD_NUMBER="${BUILD_NUMBER:-209.0}"
OUT_DIR="$ROOT_DIR/build/legacy"
WORK_DIR="$OUT_DIR/work"
APP="$OUT_DIR/Azimuth.app"
CONTENTS="$APP/Contents"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$APP" "$WORK_DIR"
mkdir -p "$WORK_DIR" "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"

xcodebuild -resolvePackageDependencies -project Azimuth.xcodeproj -scheme Azimuth \
    -derivedDataPath "$WORK_DIR/dd" >"$WORK_DIR/resolve.log" 2>&1
SPARKLE_XCF="$(find "$WORK_DIR/dd/SourcePackages/artifacts" -name Sparkle.xcframework -maxdepth 4 | head -1)"
SPARKLE_SLICE="$SPARKLE_XCF/macos-arm64_x86_64"

SWIFT_FLAGS=(
    -O -sdk "$SDK" -swift-version 5 -module-name Azimuth -default-isolation MainActor
    -enable-upcoming-feature DisableOutwardActorInference
    -enable-upcoming-feature GlobalActorIsolatedTypesUsability
    -enable-upcoming-feature InferIsolatedConformances
    -enable-upcoming-feature InferSendableFromCaptures
    -enable-upcoming-feature MemberImportVisibility
    -enable-upcoming-feature NonisolatedNonsendingByDefault
    -F "$SPARKLE_SLICE" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks
)
SOURCES=(${(f)"$(find Azimuth -name '*.swift' | sort)"})

print "▸ compile x86_64 (10.13) and arm64 (11.0)"
xcrun swiftc -target x86_64-apple-macosx10.13 "${SWIFT_FLAGS[@]}" $SOURCES -o "$WORK_DIR/Azimuth-x86_64"
xcrun swiftc -target arm64-apple-macos11 "${SWIFT_FLAGS[@]}" $SOURCES -o "$WORK_DIR/Azimuth-arm64"
lipo -create "$WORK_DIR/Azimuth-x86_64" "$WORK_DIR/Azimuth-arm64" -output "$CONTENTS/MacOS/Azimuth"

print "▸ resources and Info.plist"
xcrun actool Azimuth/Assets.xcassets --compile "$CONTENTS/Resources" --platform macosx \
    --minimum-deployment-target 10.13 --app-icon AppIcon --accent-color AccentColor \
    --output-partial-info-plist "$WORK_DIR/assets.plist" >"$WORK_DIR/actool.log"
sed -e 's|$(DEVELOPMENT_LANGUAGE)|en|; s|$(EXECUTABLE_NAME)|Azimuth|; s|$(PRODUCT_NAME)|Azimuth|' \
    -e "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|$BUNDLE_ID|; s|\$(MARKETING_VERSION)|$MARKETING_VERSION|" \
    -e "s|\$(CURRENT_PROJECT_VERSION)|$BUILD_NUMBER|; s|\$(MACOSX_DEPLOYMENT_TARGET)|10.13|" \
    -e 's|$(AZIMUTH_LSUIELEMENT)|1|' Azimuth/Info.plist >"$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" -c "Add :CFBundleIconName string AppIcon" \
    "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Info.plist" >/dev/null

print "▸ Sparkle.framework (nested components signed inside-out)"
ditto "$SPARKLE_SLICE/Sparkle.framework" "$CONTENTS/Frameworks/Sparkle.framework"
SPARKLE_B="$CONTENTS/Frameworks/Sparkle.framework/Versions/B"
for component in "$SPARKLE_B"/XPCServices/*.xpc(N) "$SPARKLE_B/Autoupdate" "$SPARKLE_B/Updater.app"; do
    codesign --force --sign "$SIGN_IDENTITY" --timestamp --options runtime "$component"
done
codesign --force --sign "$SIGN_IDENTITY" --timestamp --options runtime "$CONTENTS/Frameworks/Sparkle.framework"

./scripts/legacy-bundle-runtime.sh "$APP" "$SIGN_IDENTITY"
EXPECT_AUTHORITY="${SIGN_IDENTITY%%:*}" ./scripts/legacy-bundle-gate.sh "$APP" --signed
print "✓ $APP ($MARKETING_VERSION, build $BUILD_NUMBER, $BUNDLE_ID)"
