// Sparkle 실제 비교기로 두 버전을 비교한다: `legacy-sparkle-compare A B` → A<B면 -1, 같으면 0, A>B면 1.
// 레거시 릴리스 게이트(`legacy-version-order.sh`)가 "직전 레거시 < 후보 < 본판"을 단언할 때 쓴다.
import Foundation
import Sparkle

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: legacy-sparkle-compare <a> <b>\n".utf8))
    exit(2)
}
print(SUStandardVersionComparator.default.compareVersion(args[1], toVersion: args[2]).rawValue)
