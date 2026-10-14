// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 창별 Undo 기록과 그 설정(#170).
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// 새 테스트 파일은 scripts/harness-sources.sh 의 HARNESS_TESTS 에 추가한다(한 곳).

import CoreGraphics
import Foundation

extension CommandEngineTests {

    // #170: 창 하나의 Undo 스택 — 깊이 제한, 오래된 것부터 버리기, pop, 깊이를 줄였을 때 자르기.
    static func testUndoHistory() {
        func frame(_ index: Int) -> CGRect {
            CGRect(x: CGFloat(index) * 10, y: 25, width: 800, height: 600)
        }
        func expectFrames(_ label: String, _ history: UndoHistory, _ want: [Int]) {
            checks += 1
            if history.frames != want.map(frame) {
                failures += 1
                print("FAIL \(label): got \(history.frames.map { Int($0.minX / 10) }) want \(want)")
            }
        }
        var history = UndoHistory()
        expectName("empty history has nothing to undo", "\(String(describing: history.latest))", "nil")
        for index in 1 ... 3 {
            history.push(frame(index), depth: 5)
        }
        expectFrames("pushes keep order, oldest first", history, [1, 2, 3])
        expect("latest is the most recent push", history.latest ?? .zero, frame(3))
        // 이것을 실패시키는 것: push가 trim을 부르지 않으면 6번째가 들어가도 1이 남는다.
        for index in 4 ... 6 {
            history.push(frame(index), depth: 5)
        }
        expectFrames("over depth drops the oldest", history, [2, 3, 4, 5, 6])
        history.popLatest()
        expectFrames("pop removes the latest only", history, [2, 3, 4, 5])
        // 깊이를 줄이면 오래된 쪽부터 잘린다. 이것을 실패시키는 것: removeFirst 대신 removeLast(최근 것을 버림).
        history.trim(to: 2)
        expectFrames("lowering the depth keeps the most recent", history, [4, 5])
        history.trim(to: 10)
        expectFrames("raising the depth keeps everything", history, [4, 5])
        history.popLatest()
        history.popLatest()
        history.popLatest()
        expectName("popping an empty history is harmless", "\(history.isEmpty)", "true")
        // 깊이 1 = 예전 동작(직전 frame 하나).
        var single = UndoHistory()
        single.push(frame(1), depth: 1)
        single.push(frame(2), depth: 1)
        expectFrames("depth 1 keeps only the previous frame", single, [2])
        // 범위 밖 깊이는 clamp — 0·음수가 "아무것도 기억 안 함"이 되지 않게, 너무 큰 값이 무한정 쌓이지 않게.
        // 이것을 실패시키는 것: clamped의 max(…, lowerBound)를 지우면 깊이 0에서 push가 곧바로 비운다.
        var zero = UndoHistory()
        zero.push(frame(1), depth: 0)
        expectFrames("depth 0 is clamped to 1", zero, [1])
        expectName("default depth", "\(UndoHistory.depth.defaultValue)", "5")
        expectName("depth range", "\(UndoHistory.depth.range)", "1...20")
        // 기본 64는 설정이 생기기 전의 고정값 — 바뀌면 업데이트한 사용자의 동작이 조용히 달라진다.
        expectName("default window capacity", "\(UndoHistory.windowCapacity.defaultValue)", "64")
        expectName("window capacity range", "\(UndoHistory.windowCapacity.range)", "1...256")
    }

    // #170: 설정 화면의 숫자 칸과 저장 값이 함께 쓰는 범위·입력 해석.
    static func testBoundedIntSetting() {
        let setting = BoundedIntSetting(range: 1 ... 20, defaultValue: 5)
        // 이것을 실패시키는 것: clamped의 max 또는 min 한쪽을 지우면 범위 밖 값이 그대로 나온다.
        expectName("clamp below", "\(setting.clamped(-3))", "1")
        expectName("clamp above", "\(setting.clamped(99))", "20")
        expectName("in range stays", "\(setting.clamped(7))", "7")
        expectName("parse a number", "\(String(describing: setting.parse("12")))", "Optional(12)")
        // 이것을 실패시키는 것: parse의 trimming을 지우면 앞뒤 공백 입력이 nil이 된다.
        expectName("parse trims spaces", "\(String(describing: setting.parse(" 8 ")))", "Optional(8)")
        // 이것을 실패시키는 것: parse에서 .map(clamped)를 빼면 입력한 99가 그대로 저장으로 간다.
        expectName("parse clamps above", "\(String(describing: setting.parse("99")))", "Optional(20)")
        expectName("parse clamps zero", "\(String(describing: setting.parse("0")))", "Optional(1)")
        // 숫자가 아니면 nil — `integerValue`처럼 0으로 읽어 최솟값으로 바꾸지 않는다.
        expectName("parse rejects text", "\(String(describing: setting.parse("abc")))", "nil")
        expectName("parse rejects empty", "\(String(describing: setting.parse("")))", "nil")
        expectName("parse rejects decimals", "\(String(describing: setting.parse("2.5")))", "nil")
        expectName("parse rejects overflow", "\(String(describing: setting.parse("99999999999999999999")))", "nil")
    }

    // #170: Undo 기록을 들고 있을 창의 LRU 순서와 상한 초과 퇴출.
    static func testRecentKeys() {
        var recent = RecentKeys<Int>()
        recent.touch(1)
        recent.touch(2)
        recent.touch(3)
        expectName("evict nothing within capacity", "\(recent.evict(over: 3))", "[]")
        // 이것을 실패시키는 것: touch의 removeAll을 지우면 1이 두 번 들어가 [1, 2, 3, 1]이 된다.
        recent.touch(1)
        expectName("touch moves a key to most recent", "\(recent.keys)", "[2, 3, 1]")
        // 이것을 실패시키는 것: prefix 대신 suffix(최근 것을 버림), 또는 removeFirst 대신 removeLast.
        expectName("evict the least recent", "\(recent.evict(over: 2))", "[2]")
        expectName("evicted key is gone", "\(recent.keys)", "[3, 1]")
        recent.touch(4)
        recent.touch(5)
        // 상한을 줄이면 여러 개가 한 번에 나간다.
        expectName("lowered capacity evicts several", "\(recent.evict(over: 1))", "[3, 1, 4]")
        expectName("most recent survives", "\(recent.keys)", "[5]")
        // 이것을 실패시키는 것: max(capacity, 0)을 지우면 음수 상한에서 removeFirst가 개수를 넘겨 크래시한다.
        expectName("negative capacity evicts all", "\(recent.evict(over: -1))", "[5]")
        recent.touch(6)
        recent.touch(7)
        recent.remove(6)
        expectName("remove drops one key", "\(recent.keys)", "[7]")
        recent.removeAll()
        expectName("removeAll empties", "\(recent.keys)", "[]")
    }

    // #170: 두 Undo 설정의 기본값·저장·clamp. `CommandEngineTests+Permissions.swift`는 legacy/10.13과 바이트 단위로
    // 같아야 하므로(scripts/shared-with-legacy.txt) main 전용인 이 검사를 그 파일의 `PreferencesStore` 테스트에 넣지 않는다.
    @MainActor
    static func testUndoPreferences() {
        withTestDefaults { defaults in checkUndoPreferences(defaults) }
    }

    @MainActor
    private static func checkUndoPreferences(_ defaults: UserDefaults) {
        let store = PreferencesStore(defaults: defaults)
        expectName("undo depth defaults to 5", "\(store.undoDepth)", "5")
        store.undoDepth = 12
        expectName("undo depth persists", "\(PreferencesStore(defaults: defaults).undoDepth)", "12")
        // 이것을 실패시키는 것: setter나 getter의 clamp를 지우면 0·99가 그대로 저장되거나 읽힌다.
        store.undoDepth = 0
        expectName("undo depth set below range clamps to 1", "\(store.undoDepth)", "1")
        // getter도 clamp하므로 위 줄만으로는 setter의 clamp가 잡히지 않는다 — 저장된 값을 직접 본다.
        expectName("undo depth is stored clamped", "\(defaults.integer(forKey: "undoDepth"))", "1")
        defaults.set(99, forKey: "undoDepth")
        expectName("hand-edited undo depth clamps to 20", "\(store.undoDepth)", "20")
        expectName("undo window capacity defaults to 64", "\(store.undoWindowCapacity)", "64")
        store.undoWindowCapacity = 100
        expectName("undo window capacity persists", "\(PreferencesStore(defaults: defaults).undoWindowCapacity)", "100")
        // 이것을 실패시키는 것: setter의 clamp를 지우면 1000이 그대로 저장된다(getter의 clamp가 가리므로 저장 값을 본다).
        store.undoWindowCapacity = 1000
        expectName("undo window capacity is stored clamped", "\(defaults.integer(forKey: "undoWindowCapacity"))", "256")
        // 이것을 실패시키는 것: getter의 clamp를 지우면 손으로 넣은 0이 그대로 읽힌다.
        defaults.set(0, forKey: "undoWindowCapacity")
        expectName("hand-edited undo window capacity clamps to 1", "\(store.undoWindowCapacity)", "1")
    }
}
