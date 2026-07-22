// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 기하 배치·이동·상대 축소.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// ⚠️ AppKit/AX 비의존. 새 테스트 파일은 scripts/test.sh·coverage.sh 양쪽에 추가해야 한다.

import CoreGraphics
import Foundation

extension CommandEngineTests {

    static func testAbsolutePlacements() {
        let base = CGRect(x: 300, y: 200, width: 700, height: 500)
        let twoThird: CGFloat = 2.0 / 3.0
        expect("maximize", target(.maximize, base), workArea)
        expect("right 1/2", target(absolute(.horizontal, .half, .last), base),
               CGRect(x: 960, y: 200, width: 960, height: 500))
        expect("left 1/3", target(absolute(.horizontal, .third, .first), base),
               CGRect(x: 0, y: 200, width: 640, height: 500))
        expect("center 1/3", target(absolute(.horizontal, .third, .center), base),
               CGRect(x: 640, y: 200, width: 640, height: 500))
        expect("right 1/3", target(absolute(.horizontal, .third, .last), base),
               CGRect(x: 1280, y: 200, width: 640, height: 500))
        expect("left 2/3", target(absolute(.horizontal, .twoThird, .first), base),
               CGRect(x: 0, y: 200, width: 1280, height: 500))
        expect("bottom 1/2 keeps x/width", target(absolute(.vertical, .half, .last), base),
               CGRect(x: 300, y: 552.5, width: 700, height: 527.5))
        expect("top 2/3", target(absolute(.vertical, .twoThird, .first), base),
               CGRect(x: 300, y: 25, width: 700, height: 1055 * twoThird))
    }

    static func testAxisIndependentComposition() {
        var frame = target(.maximize, CGRect(x: 10, y: 10, width: 100, height: 100))
        frame = target(absolute(.horizontal, .half, .first), frame)
        frame = target(absolute(.vertical, .half, .first), frame)
        expect("maximize -> left 1/2 -> top 1/2 = top-left quarter", frame,
               CGRect(x: 0, y: 25, width: 960, height: 527.5))
    }

    static func testMoves() {
        expect("move right clamps to work-area edge", target(.move(.right), CGRect(x: 1700, y: 25, width: 400, height: 300)),
               CGRect(x: 1520, y: 25, width: 400, height: 300))
        expect("move left clamps to work-area edge", target(.move(.left), CGRect(x: 100, y: 25, width: 400, height: 300)),
               CGRect(x: 0, y: 25, width: 400, height: 300))
        expect("move center", target(.move(.center), CGRect(x: 0, y: 25, width: 400, height: 300)),
               CGRect(x: 760, y: 402.5, width: 400, height: 300))
        expect("oversize window pins to top-left, not negative", target(.move(.right), CGRect(x: 0, y: 25, width: 2000, height: 300)),
               CGRect(x: 0, y: 25, width: 2000, height: 300))
        expect("move up clamps", target(.move(.up), CGRect(x: 100, y: 400, width: 400, height: 300)),
               CGRect(x: 100, y: 100, width: 400, height: 300))
        expect("move down clamps", target(.move(.down), CGRect(x: 100, y: 400, width: 400, height: 300)),
               CGRect(x: 100, y: 700, width: 400, height: 300))
    }

    static func testRelativeHalves() {
        var frame = CGRect(x: 0, y: 25, width: 960, height: 1055)
        frame = target(.relativeHalf(.left), frame)
        expect("relative left halves width, keeps left edge", frame, CGRect(x: 0, y: 25, width: 480, height: 1055))
        frame = target(.relativeHalf(.left), frame)
        expect("relative left is cumulative", frame, CGRect(x: 0, y: 25, width: 240, height: 1055))
        expect("relative right keeps right edge", target(.relativeHalf(.right), CGRect(x: 0, y: 25, width: 800, height: 1055)),
               CGRect(x: 400, y: 25, width: 400, height: 1055))
        expect("relative bottom keeps bottom edge", target(.relativeHalf(.bottom), CGRect(x: 0, y: 25, width: 800, height: 600)),
               CGRect(x: 0, y: 325, width: 800, height: 300))
        expect("relative top keeps top edge", target(.relativeHalf(.top), CGRect(x: 0, y: 25, width: 800, height: 600)),
               CGRect(x: 0, y: 25, width: 800, height: 300))
    }

    static func testRelativeTwoThirds() {
        expect("relative 2/3 left keeps left edge, width×2/3",
               target(.relativeTwoThird(.left), CGRect(x: 0, y: 25, width: 900, height: 1055)),
               CGRect(x: 0, y: 25, width: 600, height: 1055))
        expect("relative 2/3 right keeps right edge",
               target(.relativeTwoThird(.right), CGRect(x: 0, y: 25, width: 900, height: 1055)),
               CGRect(x: 300, y: 25, width: 600, height: 1055))
        expect("relative 2/3 top keeps top edge, height×2/3",
               target(.relativeTwoThird(.top), CGRect(x: 0, y: 25, width: 800, height: 900)),
               CGRect(x: 0, y: 25, width: 800, height: 600))
        expect("relative 2/3 bottom keeps bottom edge",
               target(.relativeTwoThird(.bottom), CGRect(x: 0, y: 25, width: 800, height: 900)),
               CGRect(x: 0, y: 325, width: 800, height: 600))
        // 효과 조합: 2/3 후 1/2 = 1/3 (절대 1/3 명령 없이도 상대적으로 도달).
        var frame = CGRect(x: 0, y: 25, width: 900, height: 1055)
        frame = target(.relativeTwoThird(.left), frame)
        frame = target(.relativeHalf(.left), frame)
        expect("2/3 then 1/2 composes to 1/3 width", frame, CGRect(x: 0, y: 25, width: 300, height: 1055))
    }

    static func testRelativeShrinkFloor() {
        // 한 변 하한 100pt: 그 아래로는 줄어들지 않는다(반복 축소가 0으로 수렴하는 것 방지).
        expect("relative half floors width at 100 (not 60)", target(.relativeHalf(.left), CGRect(x: 0, y: 25, width: 120, height: 400)),
               CGRect(x: 0, y: 25, width: 100, height: 400))
        expect("relative 2/3 floors height at 100", target(.relativeTwoThird(.top), CGRect(x: 0, y: 25, width: 400, height: 120)),
               CGRect(x: 0, y: 25, width: 400, height: 100))
        // 이미 하한보다 작은 창은 그대로(확대 안 함).
        expect("already-below-floor window is unchanged", target(.relativeHalf(.left), CGRect(x: 0, y: 25, width: 80, height: 400)),
               CGRect(x: 0, y: 25, width: 80, height: 400))
        // 우측 앵커 + 하한: 오른쪽 모서리 고정 유지.
        expect("right anchor keeps right edge with floor", target(.relativeTwoThird(.right), CGRect(x: 0, y: 25, width: 120, height: 400)),
               CGRect(x: 20, y: 25, width: 100, height: 400))
    }

    // 작업영역보다 큰 창의 move(.center)가 음수 origin(화면 밖)으로 가지 않고 좌상단에 핀(B4).
    static func testCenterClamp() {
        expect("oversize center pins to top-left, not negative",
               target(.move(.center), CGRect(x: 50, y: 40, width: 2000, height: 1200)),
               CGRect(x: 0, y: 25, width: 2000, height: 1200))
    }

    static func testGapMaximize() {
        let base = CGRect(x: 300, y: 200, width: 700, height: 500)
        // 정상: 작업영역(0,25,1920,1055)을 사방 12pt 안쪽으로.
        expect("gap maximize insets workArea by 12 on all sides", target(.maximizeGaps, base),
               CGRect(x: 12, y: 37, width: 1896, height: 1031))
        // gap 유지: 현재 창과 무관하게 작업영역 기준(절대 배치).
        expect("gap maximize ignores current frame", target(.maximizeGaps, CGRect(x: 0, y: 25, width: 100, height: 100)),
               CGRect(x: 12, y: 37, width: 1896, height: 1031))
    }

    static func testGapMaximizeDegenerate() {
        // 퇴화 작업영역: inset 결과 한 변이 100pt 미만 → 평범한 maximize(workArea)로 폴백(0/음수 크기 방지).
        let tiny = CGRect(x: 0, y: 0, width: 120, height: 400)
        let got = FrameCalculator.targetFrame(for: .maximizeGaps, current: CGRect(x: 10, y: 10, width: 50, height: 50),
                                              workArea: tiny)
        expect("degenerate gap maximize falls back to full workArea", got, tiny)
        // 극단: 작업영역 폭이 2*gap(24) 미만 → insetBy가 음수 폭(또는 CGRectNull)을 만든다 → 가드가 잡아 폴백.
        let sliver = CGRect(x: 0, y: 0, width: 20, height: 400)
        let sliverGot = FrameCalculator.targetFrame(for: .maximizeGaps, current: sliver, workArea: sliver)
        expect("sub-2*gap width falls back (no negative-width rect)", sliverGot, sliver)
        // height 조건 단독 폴백(폭은 통과, 높이만 100pt 미만): 400×120 → inset 376×96 → 폴백.
        let shortWA = CGRect(x: 0, y: 0, width: 400, height: 120)
        let shortGot = FrameCalculator.targetFrame(for: .maximizeGaps, current: shortWA, workArea: shortWA)
        expect("height-only under-floor falls back", shortGot, shortWA)
    }

    // 순수 계층 폴백: undo·moveToDisplay는 현재 frame을 그대로 반환(실제 동작은 Executor).
    static func testFallbackCommands() {
        let base = CGRect(x: 300, y: 200, width: 700, height: 500)
        expect("undo returns current", target(.undo, base), base)
        expect("moveToDisplay pure fallback returns current", target(.moveToDisplay(.left), base), base)
    }
}
