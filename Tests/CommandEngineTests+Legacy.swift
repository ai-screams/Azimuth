//
//  CommandEngineTests+Legacy.swift
//  AzimuthTests
//
//  레거시판(macOS 10.13~12) 전용 순수 로직. `os.Logger`(11+) 대신 쓰는 `LogMessage`가 `privacy:` 표기를
//  메시지 전체의 공개 여부로 올바르게 접는지 고정한다 — 하나라도 공개가 아니면 전체를 private로 남겨야 한다.
//

import Foundation

extension CommandEngineTests {
    static func testLegacyLogPrivacy() {
        let count = 3
        let name = "Left Half"

        let literal: LogMessage = "plain literal"
        expectName("log literal text", literal.text, "plain literal")
        expectFlag("log literal is public", literal.isPublic, true)

        let allPublic: LogMessage = "run \(name, privacy: .public) x\(count, privacy: .public)"
        expectName("log public text", allPublic.text, "run Left Half x3")
        expectFlag("log all public", allPublic.isPublic, true)

        let unannotated: LogMessage = "run \(name)"
        expectFlag("log unannotated is private", unannotated.isPublic, false)

        let mixed: LogMessage = "run \(name, privacy: .public) by \(count)"
        expectName("log mixed text", mixed.text, "run Left Half by 3")
        expectFlag("log mixed is private", mixed.isPublic, false)

        let explicitPrivate: LogMessage = "secret \(name, privacy: .private)"
        expectFlag("log explicit private", explicitPrivate.isPublic, false)

        // 출력 경로가 레벨·공개 여부마다 `os_log`까지 도달하는지(크래시·형식 오류 없이) 한 번씩 밟는다.
        Log.app.debug("harness debug \(count, privacy: .public)")
        Log.app.info("harness info \(name)")
        Log.windows.error("harness error \(name, privacy: .public)")
        checks += 1
    }

    static func expectFlag(_ label: String, _ got: Bool, _ want: Bool) {
        checks += 1
        if got != want {
            failures += 1
            print("FAIL \(label): got \(got) want \(want)")
        }
    }
}

extension CommandEngineTests {
    static func testUpdateFeedSelection() {
        // 10.13~10.15는 주 버전 10, 11·12는 그대로 — 전부 레거시 목록.
        for major in [10, 11, 12] {
            expectName("feed for macOS \(major)", UpdateFeed.url(forMajorVersion: major), UpdateFeed.legacyURL)
        }
        // 13부터는 본판 목록으로 옮겨 간다(이주).
        for major in [13, 14, 26, 27] {
            expectName("feed for macOS \(major)", UpdateFeed.url(forMajorVersion: major), UpdateFeed.mainURL)
        }
        expectFlag("feeds differ", UpdateFeed.mainURL != UpdateFeed.legacyURL, true)
    }

    static func testVersionDisplay() {
        let show = { (build: String?) in VersionDisplay.string(prefix: "Version", short: "1.7.2", build: build) }
        // 레거시 빌드 번호 209.N은 "Legacy N"으로 보인다.
        expectName("legacy build", show("209.3"), "Version 1.7.2 Legacy 3")
        expectName("legacy build 0", show("209.0"), "Version 1.7.2 Legacy 0")
        // 그 밖의 빌드 번호는 괄호 표기 그대로(본판과 같은 규칙).
        expectName("main build", show("212"), "Version 1.7.2 (212)")
        expectName("other dotted build", show("210.1"), "Version 1.7.2 (210.1)")
        expectName("not a number after 209", show("209.x"), "Version 1.7.2 (209.x)")
        expectName("three parts", show("209.1.2"), "Version 1.7.2 (209.1.2)")
        expectName("same as short", show("1.7.2"), "Version 1.7.2")
        expectName("no build", show(nil), "Version 1.7.2")
        expectName("no short", VersionDisplay.string(prefix: "Azimuth", short: nil, build: nil), "Azimuth —")
    }
}
