#!/bin/zsh
#
# Azimuth 레거시판(macOS 10.13~12) 배포본 빌드:
#   archive → Developer ID export → 10.13 런타임 동봉·재서명 → 번들 게이트 → 공증 → staple → DMG
#
# 결과물: dist/Azimuth-<version>-legacy-<N>.dmg  (드래그-투-Applications, Gatekeeper 통과)
# Xcode 26.3 이하가 필요하다(27은 10.13 타깃을 거부한다).
#
# 정공법: Developer ID Application 인증서로 정상 서명 + Hardened Runtime + Apple 공증.
# (Apple Development/ad-hoc 서명은 배포 불가 — 공증이 거부된다.)
#
# ── 필요한 환경변수 ───────────────────────────────────────────────────────────
#   DEVELOPMENT_TEAM        Apple Developer Team ID (예: 7K6MK3KP9K)               [필수]
#   DEVELOPER_ID_IDENTITY   codesign 인증서 이름. 기본 "Developer ID Application"   [선택]
#
#   공증 자격은 아래 둘 중 하나:
#   (A) NOTARY_PROFILE      `xcrun notarytool store-credentials`로 저장한 키체인 프로필 이름
#   (B) APPLE_ID + APPLE_APP_PASSWORD(앱 암호) + DEVELOPMENT_TEAM
#
#   VERSION                 레거시 태그 `legacy-vX.Y.Z-N`(또는 `X.Y.Z-N`). 미지정 시 최신 legacy-v* 태그  [선택]
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Azimuth"
SCHEME="Azimuth"
PROJECT="$ROOT_DIR/Azimuth.xcodeproj"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/$APP_NAME.app"
EXPORT_OPTS="$BUILD_DIR/ExportOptions.plist"

DEVELOPER_ID_IDENTITY="${DEVELOPER_ID_IDENTITY:-Developer ID Application}"

# ── 사전 점검 ────────────────────────────────────────────────────────────────
die() { print -u2 "release: $1"; exit 1; }

[[ -n "${DEVELOPMENT_TEAM:-}" ]] || die "DEVELOPMENT_TEAM 미설정 (Apple Team ID)"
if [[ -z "${NOTARY_PROFILE:-}" ]]; then
    [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]] \
        || die "공증 자격 없음: NOTARY_PROFILE 또는 (APPLE_ID + APPLE_APP_PASSWORD) 필요"
fi

# 버전 결정: 인자 > VERSION > 최신 legacy-v* 태그
TAG="${1:-${VERSION:-}}"
if [[ -z "$TAG" ]]; then
    TAG="$(git describe --tags --abbrev=0 --match 'legacy-v*' 2>/dev/null)" || die "legacy-v* 태그 없음"
fi
# 형식 방어: `legacy-vX.Y.Z-N`만 허용. CI에서 이 값은 git 태그(github.ref_name)에서 오는데, 태그명에
# 셸/경로/XML 특수문자가 들어가면 DMG 경로·ExportOptions.plist를 오염시킬 수 있다(모든 사용처는
# 인용돼 인젝션은 불가하나, 방어적으로 형식을 강제한다).
[[ "$TAG" =~ '^(legacy-v)?([0-9]+\.[0-9]+\.[0-9]+)-([1-9][0-9]{0,5})$' ]] \
    || die "예상치 못한 VERSION 거부: '$TAG' (legacy-vX.Y.Z-N 형식만 허용, N은 1~999999)"
VERSION="${match[2]}"
LEGACY_N="${match[3]}"

# N은 버전별 회차가 아니라 **레거시 채널 전체의 일련번호**다(1.7.2-3 다음 1.7.3이면 -4). 빌드 번호가
# 209.N이라 N이 줄면 Sparkle이 새 릴리스를 옛것으로 보고 제안하지 않는다 → 기존 legacy-v* 태그의 최대 N보다
# 커야 한다(CI 체크아웃은 fetch-depth: 0이어야 태그가 다 보인다).
PREV_MAX_N=0
for other in ${(f)"$(git tag --list 'legacy-v*')"}; do
    [[ "$other" == "legacy-v$VERSION-$LEGACY_N" ]] && continue
    [[ "$other" =~ '-([0-9]{1,6})$' ]] && (( match[1] > PREV_MAX_N )) && PREV_MAX_N=${match[1]}
done
(( LEGACY_N > PREV_MAX_N )) || die "레거시 일련번호 N=$LEGACY_N 이 기존 최대 $PREV_MAX_N 보다 크지 않다"
DMG="$DIST_DIR/$APP_NAME-$VERSION-legacy-$LEGACY_N.dmg"

# CFBundleVersion(=CURRENT_PROJECT_VERSION)은 Sparkle이 "더 최신인가"를 비교하는 값이다.
# 레거시판은 `209.N`: N은 태그의 레거시 회차(단조 증가), 209는 본판 빌드 번호(커밋 수, 210 이상)보다
# 늘 작아서 13+로 올라간 레거시 사용자가 본판을 더 새것으로 받는다. 짧은 버전(CFBundleShortVersionString)은
# 기반 본판 버전 X.Y.Z. 화면에는 "X.Y.Z Legacy N"으로 보인다(`VersionDisplay.legacyBuildMajor`와 같은 값).
LEGACY_BUILD_MAJOR=209
BUILD_NUMBER="$LEGACY_BUILD_MAJOR.$LEGACY_N"

print "▸ Azimuth $VERSION Legacy $LEGACY_N (build $BUILD_NUMBER) 배포본 빌드 (team=$DEVELOPMENT_TEAM, id='$DEVELOPER_ID_IDENTITY')"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# ── 1) Archive (Release + Hardened Runtime, Developer ID 서명) ────────────────
print "▸ [1/6] archive…"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_IDENTITY" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    | tail -3

# ── 2) ExportOptions.plist (developer-id) ────────────────────────────────────
cat > "$EXPORT_OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$DEVELOPMENT_TEAM</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>$DEVELOPER_ID_IDENTITY</string>
    <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

# ── 3) Export (서명된 .app) ──────────────────────────────────────────────────
print "▸ [2/6] export (Developer ID)…"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTS" \
    | tail -3
[[ -d "$APP" ]] || die "export 실패: $APP 없음"

# ── 3.5) 10.13 런타임 동봉·재서명 → 번들 게이트(서명 포함). 공증은 동봉 런타임까지 포함해 받는다.
print "▸ [2.5/6] 10.13 런타임 동봉 + 번들 게이트…"
"$ROOT_DIR/scripts/legacy-bundle-runtime.sh" "$APP" "$DEVELOPER_ID_IDENTITY"
EXPECT_TEAM="$DEVELOPMENT_TEAM" "$ROOT_DIR/scripts/legacy-bundle-gate.sh" "$APP" --signed

# ── 4) 서명/Hardened Runtime 검증 ────────────────────────────────────────────
print "▸ [3/6] 서명 검증…"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvvv "$APP" 2>&1 | grep -iE "^Authority=Developer ID|runtime" || \
    die "Developer ID/Hardened Runtime 확인 실패 — 인증서를 점검하라"

# ── 5) 공증 (notarytool) + staple ────────────────────────────────────────────
print "▸ [4/6] 공증 제출 (수 분 소요)…"
ZIP="$BUILD_DIR/$APP_NAME.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
else
    xcrun notarytool submit "$ZIP" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --team-id "$DEVELOPMENT_TEAM" \
        --wait
fi
print "▸ [5/6] staple…"
xcrun stapler staple "$APP"

# ── 6) DMG (드래그-투-Applications) ──────────────────────────────────────────
print "▸ [6/6] DMG 생성…"
STAGE="$BUILD_DIR/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"

# 앱 아이콘으로 DMG 볼륨 아이콘(.icns) 생성 → create-dmg --volicon에 사용.
ICONSET="$BUILD_DIR/$APP_NAME.iconset"
VOLICON="$BUILD_DIR/$APP_NAME.icns"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
cp "$ROOT_DIR/$APP_NAME/Assets.xcassets/AppIcon.appiconset/"icon_*.png "$ICONSET/"
iconutil -c icns "$ICONSET" -o "$VOLICON"

# DMG 창 배경(브랜드 다크 네이비 + 설치 화살표). 좌표는 540×380, 아이콘 100.
# Retina 선명도: 1x+2x PNG를 hidpi multi-rep TIFF로 결합해 Finder가 화면 배율에
# 맞는 rep을 고르게 한다(create-dmg 1.2.3은 @2x 파일을 자동 인식하지 않으므로
# 단일 TIFF로 넘긴다). tiffutil은 Command Line Tools에 포함.
BG_SRC="$ROOT_DIR/scripts/dmg"
BG="$BUILD_DIR/background.tiff"
tiffutil -cathidpicheck "$BG_SRC/background.png" "$BG_SRC/background@2x.png" -out "$BG" >/dev/null

if command -v create-dmg >/dev/null 2>&1; then
    # create-dmg는 성공해도 종료코드가 비정상일 때가 있어 가드한다.
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "$VOLICON" \
        --background "$BG" \
        --window-size 540 380 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 140 200 \
        --app-drop-link 400 200 \
        --no-internet-enable \
        "$DMG" "$STAGE" || true
fi
if [[ ! -f "$DMG" ]]; then
    print "  (create-dmg 미사용/실패 → hdiutil 폴백)"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
fi

# DMG 컨테이너도 Developer ID 서명 → 공증 → staple(다운로드 시 경고 0, spctl open 통과).
# 앱은 이미 공증·staple됐지만, 배포 산출물인 DMG 자체에도 서명+티켓을 박는다(정석 순서).
print "▸ [+] DMG 서명 + 공증 + staple…"
codesign --force --timestamp --sign "$DEVELOPER_ID_IDENTITY" "$DMG"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
else
    xcrun notarytool submit "$DMG" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --team-id "$DEVELOPMENT_TEAM" \
        --wait
fi
xcrun stapler staple "$DMG"

print "✅ 완료: $DMG"
ls -la "$DMG" | cat
