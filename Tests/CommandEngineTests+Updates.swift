// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — Sparkle 업데이트 창의 버전 표기("v1.7.2").
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// 본판과 legacy/10.13 브랜치가 같은 파일을 쓴다.

import Foundation

extension CommandEngineTests {
    static func testUpdateVersionText() {
        let label = UpdateVersionText.label
        expectName("main label", label("1.7.2", "212"), "v1.7.2")
        expectName("legacy label", label("1.7.2", "209.1"), "v1.7.2 Legacy 1")
        expectName("no double v", label("v1.7.2", "212"), "v1.7.2")
        expectName("no double V", label("V1.7.2", "212"), "V1.7.2")
        expectName("trims spaces", label(" 1.7.2 ", nil), "v1.7.2")
        expectName("empty short", label("", "212"), "—")
        expectName("unknown short", label(nil, nil), "—")
        // 209.N만 레거시로 본다.
        expectName("209 alone is not legacy", label("1.7.2", "209"), "v1.7.2")
        expectName("209.x is not legacy", label("1.7.2", "209.x"), "v1.7.2")
        expectName("209.1.2 is not legacy", label("1.7.2", "209.1.2"), "v1.7.2")
        expectName("210.1 is not legacy", label("1.7.2", "210.1"), "v1.7.2")

        func pair(_ updateShort: String?, _ updateBuild: String?, _ bundleShort: String?, _ bundleBuild: String?)
            -> String {
            let texts = UpdateVersionText.pair(
                updateShort: updateShort, updateBuild: updateBuild, bundleShort: bundleShort, bundleBuild: bundleBuild
            )
            return "\(texts.update) | \(texts.bundle)"
        }
        expectName("main update", pair("1.7.3", "220", "1.7.2", "212"), "v1.7.3 | v1.7.2")
        expectName("legacy 1 -> 2", pair("1.7.2", "209.2", "1.7.2", "209.1"), "v1.7.2 Legacy 2 | v1.7.2 Legacy 1")
        // 13 이상에서 레거시가 본판으로 옮겨 갈 때.
        expectName("legacy -> main migration", pair("1.7.2", "210", "1.7.2", "209.1"), "v1.7.2 | v1.7.2 Legacy 1")
        // 같은 짧은 버전·다른 빌드면 괄호로 구분(Sparkle 기본 규칙).
        expectName("same label, different builds", pair("1.7.2", "213", "1.7.2", "212"),
                   "v1.7.2 (213) | v1.7.2 (212)")
        expectName("same label, same build", pair("1.7.2", "212", "1.7.2", "212"), "v1.7.2 | v1.7.2")
        expectName("same label, empty build", pair("1.7.2", "", "1.7.2", "212"), "v1.7.2 | v1.7.2")
        expectName("same label, missing build", pair("1.7.2", nil, "1.7.2", "212"), "v1.7.2 | v1.7.2")
    }
}
