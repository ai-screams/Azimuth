//
//  AboutContent.swift
//  Azimuth
//
//  About 문구와 링크. 설정 창 About 화면이 쓴다(앱 메뉴 "About Azimuth"도 그 화면을 연다, #176).
//

import Foundation

nonisolated enum AboutContent {
    enum Tint {
        case none
        case pink
        case orange
    }

    struct Link {
        let title: String
        let symbol: String
        let url: URL
        let tint: Tint
    }

    static let appName = "Azimuth"
    static let tagline =
        "A keyboard-driven window manager for macOS. Snap, throw, and arrange windows "
            + "across your displays with predictable shortcuts — no mouse, no guesswork."

    static let links: [Link] = [
        link("Homepage", "globe", "https://ai-scream.ai/Azimuth/", .none),
        link("Report an Issue", "ladybug", "https://github.com/ai-screams/Azimuth/issues/new", .none),
        link("Sponsor", "heart.fill", "https://github.com/sponsors/ai-screams", .pink),
        link("Support on Ko-fi", "cup.and.saucer.fill", "https://ko-fi.com/pignuante", .orange)
    ]

    static func copyright(in bundle: Bundle = .main) -> String {
        bundle.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© 2026 ai-screams"
    }

    /// 고정 문자열이라 URL이 만들어지지 않으면 오타다(개발 중에 바로 드러나게 한다).
    private static func link(_ title: String, _ symbol: String, _ url: String, _ tint: Tint) -> Link {
        guard let parsed = URL(string: url) else { preconditionFailure("invalid About link: \(url)") }
        return Link(title: title, symbol: symbol, url: parsed, tint: tint)
    }
}
