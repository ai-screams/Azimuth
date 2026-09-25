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
