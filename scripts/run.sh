#!/bin/zsh

# 권한(Accessibility 등)이 필요한 실행/테스트는 반드시 이 스크립트로 한다.
#
# `make build`(scripts/build.sh)는 CODE_SIGNING_ALLOWED=NO로 빌드해 ad-hoc(linker-signed)
# 산출물을 만든다. ad-hoc 서명은 빌드마다 cdhash가 바뀌어 designated requirement가 불안정하고,
# 그러면 TCC가 매번 "다른 앱"으로 보고 Accessibility 권한이 무효화된다(권한 꼬임).
#
# 이 스크립트는 안정적인 Apple Development 정체성으로 서명해 빌드한다. designated requirement가
# `identifier "com.aiscream.Azimuth" + Apple Development 리프`에 고정되므로, 같은 서명으로 재빌드해도
# 한 번 부여한 권한이 유지된다. 이것이 정공법이다(권한 우회·검사 무력화 금지).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# 머신/계정이 달라도 덮어쓸 수 있도록 환경변수로 재정의 가능. 기본값은 프로젝트의 개발팀.
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-7K6MK3KP9K}"

# CODE_SIGNING_ALLOWED를 끄지 않는다 = Apple Development로 정상 서명.
xcodebuild \
    -project "$ROOT_DIR/Azimuth.xcodeproj" \
    -scheme Azimuth \
    -configuration Debug \
    -destination "platform=macOS" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    build

# 빌드 산출물 경로를 빌드 설정에서 직접 읽는다(하드코딩 금지).
APP_PATH="$(
    xcodebuild \
        -project "$ROOT_DIR/Azimuth.xcodeproj" \
        -scheme Azimuth \
        -configuration Debug \
        -showBuildSettings 2>/dev/null \
    | awk -F' = ' '
        / BUILT_PRODUCTS_DIR /{dir=$2}
        / FULL_PRODUCT_NAME /{name=$2}
        END{print dir "/" name}
    '
)"

echo "Signed build: $APP_PATH"
codesign -dvvv "$APP_PATH" 2>&1 | grep -iE "^Authority=Apple Development|^TeamIdentifier" || true

# 이전 인스턴스를 종료해 새 서명 빌드가 뜨도록 한다.
pkill -x Azimuth 2>/dev/null || true

open "$APP_PATH"
echo "Launched ✅ (Apple Development signed — Accessibility 권한 유지됨)"
