// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 첫 실행 연습 창 안내(단계, Undo 기록, 도달 판정).
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).

import CoreGraphics
import Foundation

extension CommandEngineTests {

    // 연습 창이 실제로 움직이는 순서대로 흘린다: Left 1/2 → Maximize → Undo → 완료.
    // 이것을 실패시키는 것: 다른 명령으로도 단계가 넘어가는 것, 목표에 닿지 않아도 넘어가는 것,
    // 자리가 그대로인 이동을 Undo 기록에 남기는 것, Undo가 기록을 꺼내지 않는 것, 단계 순서가 바뀌는 것.
    static func testPracticeSession() {
        let workArea = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let start = CGRect(x: 400, y: 300, width: 520, height: 360)
        var session = PracticeSession()
        func moved(_ command: WindowCommand, _ target: CGRect, _ actual: CGRect) -> String {
            "\(session.didMove(command, target: target, actual: actual))"
        }
        func step() -> String {
            "\(session.step) history=\(session.history.count)"
        }

        // 이번 단계가 아닌 명령: 창은 움직이지만 단계는 그대로다.
        let gapped = session.target(for: .maximizeGaps, current: start, workArea: workArea) ?? .null
        expectName("other command keeps the step", moved(.maximizeGaps, gapped, gapped), "false")
        expectName("other command is recorded for undo", step(), "leftHalf history=1")
        _ = session.target(for: .undo, current: gapped, workArea: workArea)

        let left = session.target(for: .snapThrow(.left), current: start, workArea: workArea) ?? .null
        expect("left half target", left, CGRect(x: 0, y: 25, width: 720, height: 875))
        let short = CGRect(x: 0, y: 25, width: 700, height: 875)
        expectName("short of the target does not count", moved(.snapThrow(.left), left, short), "false")
        expectName("reaching left half advances", moved(.snapThrow(.left), left, left), "true")
        expectName("after left half", step(), "maximize history=1")

        let full = session.target(for: .maximize, current: left, workArea: workArea) ?? .null
        expect("maximize target", full, workArea)
        _ = session.didMove(.maximize, target: full, actual: full)
        let again = session.target(for: .maximize, current: full, workArea: workArea) ?? .null
        expectName("no-op move is not recorded", step(), "undo history=2")

        let back = session.target(for: .undo, current: again, workArea: workArea) ?? .null
        expect("undo returns to left half", back, left)
        expectName("undo completes", moved(.undo, back, back), "true")
        expectName("done", step(), "done history=1")

        var empty = PracticeSession()
        let noUndo = empty.target(for: .undo, current: start, workArea: workArea)
        expectName("undo without history stays", "\(noUndo == nil)", "true")
        let display = empty.target(for: .moveToDisplay(.right), current: start, workArea: workArea)
        expectName("display move stays", "\(display == nil)", "true")
        expectName("step count", "\(PracticeStep.tryCount)", "3")
        let nudged = CGRect(x: 1, y: 27, width: 719, height: 873)
        expectName("within tolerance", "\(PracticeSession.isReached(actual: nudged, target: left))", "true")

        // 이것을 실패시키는 것: Undo 기록 상한(20)을 지우는 것.
        var capped = PracticeSession()
        var frame = start
        for index in 0 ..< PracticeSession.historyLimit + 5 {
            let side: WindowCommand = index.isMultiple(of: 2) ? .snapThrow(.left) : .snapThrow(.right)
            frame = capped.target(for: side, current: frame, workArea: workArea) ?? frame
        }
        expectName("history is capped", "\(capped.history.count)", "\(PracticeSession.historyLimit)")
    }

    // 설정 창이 열려 있는 동안 권한이 생기는 순간을 잡는 판단.
    // 이것을 실패시키는 것: 창이 닫힌 뒤에도 계속 읽는 것, 권한이 생겨도 계속 읽는 것,
    // 창이 닫히는 순간 생긴 권한을 놓치는 것(권한보다 창을 먼저 보는 순서).
    static func testPermissionWatchPolicy() {
        func step(_ visible: Bool, _ trusted: Bool) -> String {
            "\(PermissionWatchPolicy.step(windowVisible: visible, isTrusted: trusted))"
        }
        expectName("open, not trusted", step(true, false), "keepWatching")
        expectName("open, trusted", step(true, true), "granted")
        expectName("closed, not trusted", step(false, false), "stop")
        expectName("closed, trusted", step(false, true), "granted")
    }
}
