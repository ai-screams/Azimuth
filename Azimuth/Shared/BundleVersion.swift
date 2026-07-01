//
//  BundleVersion.swift
//  Azimuth
//
//  번들 표시 버전 문자열을 한 곳에서 만든다(About 창·Settings Updates 카드 공용).
//  이전엔 두 곳에 같은 로직이 복붙돼 접두어만 달랐다 → 포맷 변경 시 한 곳만 고치도록 통합.
//

import Foundation

extension Bundle {
    /// "<prefix> <short>" 또는 build가 short와 다르면 "<prefix> <short> (<build>)".
    /// short 미상 시 "—". prefix는 호출부가 지정("Version"·"Azimuth" 등).
    func displayVersion(prefix: String) -> String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? ""
        if build.isEmpty || build == short { return "\(prefix) \(short)" }
        return "\(prefix) \(short) (\(build))"
    }
}
