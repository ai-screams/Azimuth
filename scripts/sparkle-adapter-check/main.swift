// `scripts/sparkle-adapter-check.sh`가 컴파일해 실행한다. Sparkle은 업데이트 창의 버전 표기를 ObjC 이름으로
// 찾는 optional 메서드로 묻는다 — Swift 이름이 어긋나면 빌드는 통과하고 창만 조용히 "1.7.2"로 돌아가므로
// 실제 Sparkle과 링크해 그 이름들이 응답하는지 확인한다.
import Foundation
import Sparkle

let displayer = UpdateVersionDisplayer()
var failures = 0
for name in [
    "standardUserDriverRequestsVersionDisplayer",
    "formatUpdateDisplayVersionFromUpdate:andBundleDisplayVersion:withBundleVersion:",
    "formatBundleDisplayVersion:withBundleVersion:matchingUpdate:",
] where !displayer.responds(to: NSSelectorFromString(name)) {
    print("✗ UpdateVersionDisplayer does not respond to \(name)")
    failures += 1
}
if !displayer.conforms(to: SUVersionDisplay.self) {
    print("✗ UpdateVersionDisplayer does not conform to SUVersionDisplay")
    failures += 1
}
let upToDate = displayer.formatBundleDisplayVersion("1.7.2", withBundleVersion: "212", matchingUpdate: nil)
if upToDate != "v1.7.2" {
    print("✗ up-to-date text is \(upToDate), expected v1.7.2")
    failures += 1
}
if failures > 0 { exit(1) }
print("✓ Sparkle version displayer is wired (\(upToDate))")
