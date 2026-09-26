//
//  BundleVersion.swift
//  Azimuth
//
//  번들 표시 버전 문자열을 한 곳에서 만든다(About 창·Settings Updates 카드 공용).
//  이전엔 두 곳에 같은 로직이 복붙돼 접두어만 달랐다 → 포맷 변경 시 한 곳만 고치도록 통합.
//

import Foundation

extension Bundle {
    /// 번들의 짧은 버전·빌드 번호로 `VersionDisplay.string`을 만든다. prefix는 호출부가 지정("Version"·"Azimuth" 등).
    func displayVersion(prefix: String) -> String {
        VersionDisplay.string(
            prefix: prefix,
            short: infoDictionary?["CFBundleShortVersionString"] as? String,
            build: infoDictionary?["CFBundleVersion"] as? String
        )
    }
}

/// 표시 버전 규칙(순수 함수, `make test` 대상).
nonisolated enum VersionDisplay {
    /// 레거시판 빌드 번호 `209.N`의 앞자리 — 판정과 함께 `UpdateVersionText`가 한 곳에서 갖는다(업데이트 창과
    /// About·설정창이 같은 규칙을 쓰게). 본판 빌드 번호(커밋 수, 210 이상)보다 늘 작아서 Sparkle이 13+에서 본판을
    /// 더 새것으로 본다.
    static let legacyBuildMajor = UpdateVersionText.legacyBuildMajor

    /// "<prefix> <short>", build가 short와 다르면 "<prefix> <short> (<build>)",
    /// 레거시 빌드(`209.N`)면 "<prefix> <short> Legacy <N>". short 미상 시 "—".
    static func string(prefix: String, short: String?, build: String?) -> String {
        let short = short ?? "—"
        let build = build ?? ""
        if build.isEmpty || build == short { return "\(prefix) \(short)" }
        if let sequence = UpdateVersionText.legacySequence(build: build) {
            return "\(prefix) \(short) Legacy \(sequence)"
        }
        return "\(prefix) \(short) (\(build))"
    }
}
