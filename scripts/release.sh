#!/bin/zsh
#
# Azimuth 배포본 빌드: archive → Developer ID export → 공증(notarize) → staple → DMG
#
# 결과물: dist/Azimuth-<version>.dmg  (드래그-투-Applications, Gatekeeper 통과)
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
#   VERSION                 미지정 시 git 최신 태그(앞의 v 제거), 없으면 0.0.0-dev  [선택]
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

# 버전 결정: 인자 > VERSION > git 태그 > 기본값
VERSION="${1:-${VERSION:-}}"
if [[ -z "$VERSION" ]]; then
    VERSION="$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0-dev")"
fi
VERSION="${VERSION#v}"  # 앞의 v 제거
DMG="$DIST_DIR/$APP_NAME-$VERSION.dmg"

print "▸ Azimuth $VERSION 배포본 빌드 (team=$DEVELOPMENT_TEAM, id='$DEVELOPER_ID_IDENTITY')"

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
    CURRENT_PROJECT_VERSION="$VERSION" \
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

if command -v create-dmg >/dev/null 2>&1; then
    # create-dmg는 성공해도 종료코드가 비정상일 때가 있어 가드한다.
    create-dmg \
        --volname "$APP_NAME" \
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
