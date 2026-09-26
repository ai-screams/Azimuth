# 레거시 스크립트(`legacy-check.sh`, `legacy-build-app.sh`)가 swiftc에 넘기는 언어 설정의 단일 출처.
# 두 스크립트가 source 한다(harness-sources.sh와 같은 규약: 이 파일에 `set` 줄을 넣지 않는다, 배열 정의만).
#
# 로컬 Xcode 27이 10.13 타깃을 거부해 xcodebuild 대신 swiftc를 직접 부르므로, 프로젝트 빌드 설정을 여기에
# 손으로 옮겨 둔다. `project.pbxproj`의 Swift 설정을 바꾸면 여기도 같이 바꾼다:
#   SWIFT_VERSION = 5.0                          → -swift-version 5
#   SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor    → -default-isolation MainActor
#   SWIFT_APPROACHABLE_CONCURRENCY = YES         → 아래 upcoming feature 다섯 개
#   SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES → MemberImportVisibility
LEGACY_SWIFT_FLAGS=(
    -swift-version 5 -module-name Azimuth -default-isolation MainActor
    -enable-upcoming-feature DisableOutwardActorInference
    -enable-upcoming-feature GlobalActorIsolatedTypesUsability
    -enable-upcoming-feature InferIsolatedConformances
    -enable-upcoming-feature InferSendableFromCaptures
    -enable-upcoming-feature MemberImportVisibility
    -enable-upcoming-feature NonisolatedNonsendingByDefault
)
