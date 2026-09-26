//
//  UpdateVersionText.swift
//  Azimuth
//
//  Sparkle 업데이트 창에 보일 버전 문자열 규칙(순수 함수, `make test` 대상). 예: "v1.7.2",
//  레거시판 "v1.7.2 Legacy 2". About·설정창의 "Version 1.7.2"(`BundleVersion`)와는 따로 둔다 —
//  업데이트 창만 "v" 접두어를 쓰기로 했기 때문이다.
//
//  본판과 `legacy/10.13` 브랜치가 **같은 파일**을 쓴다. 레거시 빌드 번호 `209.N`은 본판 빌드 번호(커밋 수,
//  210 이상)와 겹치지 않으므로 양쪽에서 항상 인식해도 동작이 같다.
//

import Foundation

nonisolated enum UpdateVersionText {
    /// 레거시판 빌드 번호 `209.N`의 앞자리(`scripts/release.sh`의 `LEGACY_BUILD_MAJOR`와 같아야 한다).
    static let legacyBuildMajor = "209"

    /// 레거시 빌드 번호(`209.N`)면 N, 아니면 nil.
    static func legacySequence(build: String?) -> String? {
        guard let build else { return nil }
        let parts = build.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == legacyBuildMajor, Int(parts[1]) != nil else { return nil }
        return String(parts[1])
    }

    /// "v<short>", 레거시 빌드면 "v<short> Legacy <N>". short가 이미 v로 시작하면 두 번 붙이지 않고,
    /// 비어 있으면 "—".
    static func label(short: String?, build: String?) -> String {
        let trimmed = (short ?? "").trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "—" }
        let base = trimmed.first.map { $0 == "v" || $0 == "V" } == true ? trimmed : "v\(trimmed)"
        guard let sequence = legacySequence(build: build) else { return base }
        return "\(base) Legacy \(sequence)"
    }

    /// 새 버전과 현재 버전의 표시 문자열. 둘이 같게 나오면(같은 짧은 버전, 다른 빌드) Sparkle 기본 규칙처럼
    /// 양쪽 뒤에 "(빌드)"를 붙여 구분한다 — 빌드가 비었거나 같으면 붙이지 않는다(빈 괄호 방지).
    static func pair(
        updateShort: String?, updateBuild: String?, bundleShort: String?, bundleBuild: String?
    ) -> (update: String, bundle: String) {
        let update = label(short: updateShort, build: updateBuild)
        let bundle = label(short: bundleShort, build: bundleBuild)
        guard update == bundle, let updateBuild, let bundleBuild,
              !updateBuild.isEmpty, !bundleBuild.isEmpty, updateBuild != bundleBuild
        else { return (update, bundle) }
        return ("\(update) (\(updateBuild))", "\(bundle) (\(bundleBuild))")
    }
}
