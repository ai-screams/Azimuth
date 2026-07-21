// Azimuth 명령 엔진(순수 로직) 회귀 테스트.
// Xcode 테스트 타깃 대신 swiftc로 컴파일/실행한다(scripts/test.sh, `make test`, CI).
// 대상: FrameCalculator(기하 계산) + WindowCommand(명령 모델). AppKit/AX 비의존 순수 로직만.

import CoreGraphics
import Foundation

@main
enum CommandEngineTests {
    static let workArea = CGRect(x: 0, y: 25, width: 1920, height: 1055)
    static var checks = 0
    static var failures = 0

    static func main() {
        testAbsolutePlacements()
        testAxisIndependentComposition()
        testMoves()
        testRelativeHalves()
        testRelativeTwoThirds()
        testRelativeShrinkFloor()
        testSnapHalves()
        testDisplayMove()
        testFixedAndMinWidthSnap()
        testCenterClamp()
        testAnchorOrigin()
        testFallbackCommands()
        testGapMaximize()
        testGapMaximizeDegenerate()
        testDisplayGeometry()
        testIsConstrained()
        testUsableFrame()
        testCommandGroups()
        testPrimitiveStrings()
        testCommandModel()
        testCommandHelpText()
        testCommandIdentifiers()

        if failures == 0 {
            print("PASS — all \(checks) checks")
        } else {
            print("FAIL — \(failures)/\(checks) checks failed")
            exit(1)
        }
    }

    // MARK: - helpers

    private static func approx(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }

    private static func expect(_ label: String, _ got: CGRect, _ want: CGRect) {
        checks += 1
        let same = approx(got.minX, want.minX) && approx(got.minY, want.minY)
            && approx(got.width, want.width) && approx(got.height, want.height)
        if !same {
            failures += 1
            print("FAIL \(label): got \(got) want \(want)")
        }
    }

    private static func expectPoint(_ label: String, _ got: CGPoint, _ want: CGPoint) {
        checks += 1
        if !(approx(got.x, want.x) && approx(got.y, want.y)) {
            failures += 1
            print("FAIL \(label): got \(got) want \(want)")
        }
    }

    private static func expectName(_ label: String, _ got: String, _ want: String) {
        checks += 1
        if got != want {
            failures += 1
            print("FAIL \(label): got \"\(got)\" want \"\(want)\"")
        }
    }

    private static func target(_ command: WindowCommand, _ current: CGRect) -> CGRect {
        FrameCalculator.targetFrame(for: command, current: current, workArea: workArea)
    }

    private static func absolute(_ axis: Axis, _ fraction: Fraction, _ slot: Slot) -> WindowCommand {
        .absolute(AbsolutePlacement(axis: axis, fraction: fraction, slot: slot))
    }

    // MARK: - tests

    private static func testAbsolutePlacements() {
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

    private static func testAxisIndependentComposition() {
        var frame = target(.maximize, CGRect(x: 10, y: 10, width: 100, height: 100))
        frame = target(absolute(.horizontal, .half, .first), frame)
        frame = target(absolute(.vertical, .half, .first), frame)
        expect("maximize -> left 1/2 -> top 1/2 = top-left quarter", frame,
               CGRect(x: 0, y: 25, width: 960, height: 527.5))
    }

    private static func testMoves() {
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

    private static func testRelativeHalves() {
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

    private static func testRelativeTwoThirds() {
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

    private static func testRelativeShrinkFloor() {
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

    private static func testSnapHalves() {
        let base = CGRect(x: 300, y: 200, width: 700, height: 500)
        // snapThrow의 순수 폴백(스냅)은 그 방향 절반과 같다(튕기기는 Executor에서 화면 의존).
        expect("snap left = left 1/2", target(.snapThrow(.left), base), CGRect(x: 0, y: 25, width: 960, height: 1055))
        expect("snap right = right 1/2", target(.snapThrow(.right), base), CGRect(x: 960, y: 25, width: 960, height: 1055))
        expect("snap top = top 1/2", target(.snapThrow(.top), base), CGRect(x: 0, y: 25, width: 1920, height: 527.5))
        expect("snap bottom = bottom 1/2", target(.snapThrow(.bottom), base),
               CGRect(x: 0, y: 552.5, width: 1920, height: 527.5))
        expectName("opposite left", SnapEdge.left.opposite.token, "right")
        expectName("opposite top", SnapEdge.top.opposite.token, "bottom")
        expectName("snap left name", WindowCommand.snapThrow(.left).displayName, "Left 1/2")
    }

    private static func testDisplayMove() {
        let rightHalf = FrameCalculator.halfRect(.right, workArea: workArea)
        let leftHalf = FrameCalculator.halfRect(.left, workArea: workArea)
        let bottomHalf = FrameCalculator.halfRect(.bottom, workArea: workArea)
        let rightFillsRight = FrameCalculator.isSnapped(rightHalf, to: .right, workArea: workArea)
        let leftFillsRight = FrameCalculator.isSnapped(leftHalf, to: .right, workArea: workArea)
        let bottomFillsBottom = FrameCalculator.isSnapped(bottomHalf, to: .bottom, workArea: workArea)
        expectName("right half fills right", "\(rightFillsRight)", "true")
        expectName("left half does not fill right", "\(leftFillsRight)", "false")
        expectName("bottom half fills bottom", "\(bottomFillsBottom)", "true")
        // 절반보다 작은 창은 "채움"이 아니다 → snapThrow가 던지지 않고 그 절반으로 스냅.
        let smallInRight = CGRect(x: 1400, y: 400, width: 300, height: 300)
        expectName("small window in right half does not fill",
                   "\(FrameCalculator.isSnapped(smallInRight, to: .right, workArea: workArea))", "false")
        // 크기증분으로 한 셀 모자란 거의-꽉찬 창은 채움으로 인정 → 던지기.
        let nearlyRight = CGRect(x: 965, y: 30, width: 950, height: 1045)
        expectName("nearly-full right half still fills",
                   "\(FrameCalculator.isSnapped(nearlyRight, to: .right, workArea: workArea))", "true")
        // 앱 최소 크기 탓에 절반보다 '커서' 바깥(화면 가장자리)으로 넘친 창도 그 절반에 고정돼 있으면 채움.
        // (Safari가 아래 절반으로 줄 때 끝까지 안 줄어 화면 밖으로 넘치던 throw 미작동 버그 회귀 방지.)
        let bottomHalfRect = FrameCalculator.halfRect(.bottom, workArea: workArea)
        let tallerThanBottom = CGRect(x: bottomHalfRect.minX, y: bottomHalfRect.minY,
                                      width: bottomHalfRect.width, height: bottomHalfRect.height + 80)
        expectName("bottom window overshooting outer edge still fills",
                   "\(FrameCalculator.isSnapped(tallerThanBottom, to: .bottom, workArea: workArea))", "true")
        // 반대쪽 절반으로 침범하는 창(최대화 등)은 그 절반 '채움'이 아니다 → 던지지 않고 스냅.
        expectName("maximized window does not fill bottom half",
                   "\(FrameCalculator.isSnapped(workArea, to: .bottom, workArea: workArea))", "false")

        let from = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let to = CGRect(x: 2000, y: 0, width: 1000, height: 1000)
        expect("display move keeps left-half", display(CGRect(x: 0, y: 0, width: 500, height: 1000), from, to),
               CGRect(x: 2000, y: 0, width: 500, height: 1000))
        expect("display move keeps relative origin", display(CGRect(x: 250, y: 250, width: 500, height: 500), from, to),
               CGRect(x: 2250, y: 250, width: 500, height: 500))
        let small = CGRect(x: 100, y: 0, width: 600, height: 600)
        expect("display move caps into smaller", display(CGRect(x: 0, y: 0, width: 1000, height: 1000), from, small),
               CGRect(x: 100, y: 0, width: 600, height: 600))
        // M-5: 절대 크기 유지 — 대상 화면 크기가 달라도 창의 픽셀 크기를 보존한다(비례 축소하지 않음).
        // 비례였다면 200×200이 됐을 창이 절대 크기 400×400을 유지한다.
        let big = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        let smallDest = CGRect(x: 5000, y: 0, width: 1000, height: 1000)
        expect("display move preserves absolute size (no proportional shrink)",
               display(CGRect(x: 0, y: 0, width: 400, height: 400), big, smallDest),
               CGRect(x: 5000, y: 0, width: 400, height: 400))
        // 대상 화면보다 큰 축만 대상 크기로 캡(창이 화면을 넘지 않게).
        expect("display move caps oversize axis to destination",
               display(CGRect(x: 0, y: 0, width: 1500, height: 800), big, smallDest),
               CGRect(x: 5000, y: 0, width: 1000, height: 800))
        expectName("moveToDisplay name", WindowCommand.moveToDisplay(.top).displayName, "Move to Up Display")
    }

    private static func display(_ rect: CGRect, _ from: CGRect, _ to: CGRect) -> CGRect {
        FrameCalculator.displayMoveRect(rect, from: from, to: to)
    }

    // 고정폭·최소폭 앱이 좌/우 대칭으로 "스냅됨"으로 판정돼 throw 가능한지(B1/B2/B3).
    private static func testFixedAndMinWidthSnap() {
        let fixedLeft = CGRect(x: 0, y: 25, width: 800, height: 1055) // 절반(960)보다 좁은 고정폭, 좌측 붙음
        expectName("fixed-width flush-left fills left (B2)",
                   "\(FrameCalculator.isSnapped(fixedLeft, to: .left, workArea: workArea))", "true")
        let fixedRight = CGRect(x: 1120, y: 25, width: 800, height: 1055) // 같은 고정폭, 우측 붙음
        expectName("fixed-width flush-right fills right (B1 대칭)",
                   "\(FrameCalculator.isSnapped(fixedRight, to: .right, workArea: workArea))", "true")
        let minLeft = CGRect(x: 0, y: 25, width: 1100, height: 1055) // 절반보다 넓은 최소폭, 좌측 붙음
        expectName("min-width flush-left fills left (B3)",
                   "\(FrameCalculator.isSnapped(minLeft, to: .left, workArea: workArea))", "true")
        let floating = CGRect(x: 810, y: 400, width: 300, height: 300) // 어느 쪽에도 안 붙은 소형창
        expectName("floating small window fills neither (left)",
                   "\(FrameCalculator.isSnapped(floating, to: .left, workArea: workArea))", "false")
        expectName("floating small window fills neither (right)",
                   "\(FrameCalculator.isSnapped(floating, to: .right, workArea: workArea))", "false")
        // 좌측 모서리에 닿았지만 키가 작은 부유창은 "스냅됨"이 아니다(수직 커버리지<0.5 → 스냅, throw 아님).
        let shortNearLeft = CGRect(x: 10, y: 400, width: 500, height: 300)
        expectName("short edge-touching window is not snapped",
                   "\(FrameCalculator.isSnapped(shortNearLeft, to: .left, workArea: workArea))", "false")
        expectName("maximized does not fill left (both edges flush)",
                   "\(FrameCalculator.isSnapped(workArea, to: .left, workArea: workArea))", "false")
    }

    // 작업영역보다 큰 창의 move(.center)가 음수 origin(화면 밖)으로 가지 않고 좌상단에 핀(B4).
    private static func testCenterClamp() {
        expect("oversize center pins to top-left, not negative",
               target(.move(.center), CGRect(x: 50, y: 40, width: 2000, height: 1200)),
               CGRect(x: 0, y: 25, width: 2000, height: 1200))
    }

    // 제약 앱이 목표 크기에 못 미칠 때 스냅 모서리를 유지하는 anchored origin.
    private static func testAnchorOrigin() {
        let rightHalf = FrameCalculator.halfRect(.right, workArea: workArea)
        expectPoint("anchor right-half to actual width keeps right edge",
                    FrameCalculator.anchorOrigin(actualSize: CGSize(width: 1100, height: 1055),
                                                 requested: rightHalf, workArea: workArea),
                    CGPoint(x: 820, y: 25))
        let bottomHalf = FrameCalculator.halfRect(.bottom, workArea: workArea)
        expectPoint("anchor bottom-half to actual height keeps bottom edge",
                    FrameCalculator.anchorOrigin(actualSize: CGSize(width: 1920, height: 700),
                                                 requested: bottomHalf, workArea: workArea),
                    CGPoint(x: 0, y: 380))
        let leftHalf = FrameCalculator.halfRect(.left, workArea: workArea)
        expectPoint("anchor left-half keeps left edge (no shift)",
                    FrameCalculator.anchorOrigin(actualSize: CGSize(width: 1100, height: 1055),
                                                 requested: leftHalf, workArea: workArea),
                    CGPoint(x: 0, y: 25))
        // 앱 최소폭이 작업영역보다 큰 퇴화 케이스: 음수 origin이 아니라 좌상단으로 클램프.
        expectPoint("anchor clamps oversize min-width to on-screen origin",
                    FrameCalculator.anchorOrigin(actualSize: CGSize(width: 2000, height: 1055),
                                                 requested: rightHalf, workArea: workArea),
                    CGPoint(x: 0, y: 25))
    }

    // 순수 계층 폴백: undo·moveToDisplay는 현재 frame을 그대로 반환(실제 동작은 Executor).
    private static func testFallbackCommands() {
        let base = CGRect(x: 300, y: 200, width: 700, height: 500)
        expect("undo returns current", target(.undo, base), base)
        expect("moveToDisplay pure fallback returns current", target(.moveToDisplay(.left), base), base)
    }

    private static func testGapMaximize() {
        let base = CGRect(x: 300, y: 200, width: 700, height: 500)
        // 정상: 작업영역(0,25,1920,1055)을 사방 12pt 안쪽으로.
        expect("gap maximize insets workArea by 12 on all sides", target(.maximizeGaps, base),
               CGRect(x: 12, y: 37, width: 1896, height: 1031))
        // gap 유지: 현재 창과 무관하게 작업영역 기준(절대 배치).
        expect("gap maximize ignores current frame", target(.maximizeGaps, CGRect(x: 0, y: 25, width: 100, height: 100)),
               CGRect(x: 12, y: 37, width: 1896, height: 1031))
    }

    private static func testGapMaximizeDegenerate() {
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

    // DisplayGeometry 인접 화면 선택(순수 기하). Cocoa 좌표(원점 좌하단, Y 위로).
    private static func testDisplayGeometry() {
        // 현재 화면(원점). 오른쪽/왼쪽에 이웃.
        let cur = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let right = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let win = CGRect(x: 800, y: 400, width: 300, height: 200)

        expectName("right picks the right neighbor",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [left, right], window: win, edge: .right) ?? -1)", "1")
        expectName("left picks the left neighbor",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [left, right], window: win, edge: .left) ?? -1)", "0")
        // 그 방향에 이웃이 없으면 nil.
        expectName("no neighbor upward -> nil",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [left, right], window: win, edge: .top) == nil)", "true")
        // 세로 겹침 없는 후보는 방향이 맞아도 제외(오른쪽이지만 Y로 안 겹침).
        let rightButBelow = CGRect(x: 1920, y: -2000, width: 1920, height: 1080)
        expectName("direction match but no vertical overlap -> excluded",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [rightButBelow], window: win, edge: .right) == nil)", "true")
        // 세로 스택 타이브레이크: 왼쪽에 위/아래 두 화면 → 창의 수직 중심(midY)에 가까운 쪽 선택.
        // 창을 위쪽(midY=900)에 두면 위 화면(y 500..1580, 겹침) 선택; 아래 화면은 perpendicularGap 큼.
        let leftTop = CGRect(x: -1200, y: 500, width: 1200, height: 1080)
        let leftBottom = CGRect(x: -1200, y: -900, width: 1200, height: 1080)
        let winHigh = CGRect(x: 100, y: 850, width: 300, height: 200) // midY=950
        expectName("vertical-stack left picks the overlapping/closer screen (top=idx0)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [leftTop, leftBottom], window: winHigh, edge: .left) ?? -1)", "0")
        let winLow = CGRect(x: 100, y: -800, width: 300, height: 200) // midY=-700
        expectName("vertical-stack left picks the lower screen for a low window (bottom=idx1)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [leftTop, leftBottom], window: winLow, edge: .left) ?? -1)", "1")
        // 빈 후보 → nil.
        expectName("empty candidates -> nil",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [], window: win, edge: .right) == nil)", "true")

        // 수직 방향(top/bottom): 위/아래 이웃(horizontalOverlap·primaryGap top/bottom 경로 커버).
        let above = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        let below = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        expectName("top picks the above screen (idx0)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [above, below], window: win, edge: .top) ?? -1)", "0")
        expectName("bottom picks the below screen (idx1)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [above, below], window: win, edge: .bottom) ?? -1)", "1")
        // 위쪽이지만 가로로 안 겹침 → 제외.
        let aboveButRight = CGRect(x: 3000, y: 1080, width: 1920, height: 1080)
        expectName("top match but no horizontal overlap -> excluded",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [aboveButRight], window: win, edge: .top) == nil)", "true")
        // 가로 스택 타이브레이크(top): 위쪽에 좌/우 두 화면 → 창 midX에 가까운 쪽.
        let aboveLeft = CGRect(x: -600, y: 1080, width: 1200, height: 1080)   // x [-600,600]
        let aboveRight = CGRect(x: 1400, y: 1080, width: 1200, height: 1080)  // x [1400,2600]
        let winLeft = CGRect(x: 100, y: 400, width: 200, height: 200)         // midX=200
        expectName("horizontal-stack top picks x-closer screen (left=idx0)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [aboveLeft, aboveRight], window: winLeft, edge: .top) ?? -1)", "0")
        // 주축 edge-gap이 다른 두 오른쪽 화면 → 가까운(edge-gap 최소) 화면이 인접 계층으로 이긴다.
        let rightFar = CGRect(x: 4000, y: 0, width: 1920, height: 1080)   // edge-gap 큼(먼 화면)
        let rightNear = CGRect(x: 1920, y: 0, width: 1920, height: 1080)  // edge-gap 0(인접)
        expectName("right picks nearest adjacent layer (nearer=idx1)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [rightFar, rightNear], window: win, edge: .right) ?? -1)", "1")
        // M-6: 방향상 가장 가까운(edge-gap 최소) 화면이, 멀지만 창 Y에 정렬된 화면을 이긴다.
        // near는 바로 오른쪽이지만 Y가 어긋나 perpendicular gap이 크고, far는 멀지만 창 Y에 정렬됨.
        // 과거(정렬 우선)엔 far가 이겼다 — 이제는 인접 계층(near)이 이긴다.
        let nearMisaligned = CGRect(x: 1920, y: -900, width: 1920, height: 1080) // 인접, Y 어긋남
        let farAligned = CGRect(x: 4000, y: 0, width: 1920, height: 1080)        // 멀지만 Y 정렬
        expectName("nearest adjacent beats far-but-aligned (near=idx0)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: [nearMisaligned, farAligned], window: win, edge: .right) ?? -1)", "0")
    }

    // WindowFrameWriter가 anchored 보정을 걸지 판정하는 순수 임계 함수(경계값).
    private static func testIsConstrained() {
        let target = CGSize(width: 1000, height: 800)
        // 목표와 같음 → 제약 아님.
        expectName("equal size not constrained",
                   "\(FrameCalculator.isConstrained(actualSize: target, target: target, tolerance: 8))", "false")
        // tolerance 정확히 = 경계(초과 아님) → 제약 아님(> 비교).
        expectName("exactly at tolerance not constrained",
                   "\(FrameCalculator.isConstrained(actualSize: CGSize(width: 1008, height: 800), target: target, tolerance: 8))", "false")
        // tolerance 직후(1008.1) → 제약.
        expectName("just over tolerance is constrained (width)",
                   "\(FrameCalculator.isConstrained(actualSize: CGSize(width: 1008.1, height: 800), target: target, tolerance: 8))", "true")
        // 높이 축 단독 초과 → 제약.
        expectName("height-only over tolerance is constrained",
                   "\(FrameCalculator.isConstrained(actualSize: CGSize(width: 1000, height: 809), target: target, tolerance: 8))", "true")
        // 목표보다 작음 → 제약 아님(축소는 anchored 보정 대상 아님).
        expectName("smaller than target not constrained",
                   "\(FrameCalculator.isConstrained(actualSize: CGSize(width: 500, height: 400), target: target, tolerance: 8))", "false")
    }

    // L-3: AX에서 읽은 frame의 유효성(유한·양수 크기) 방어 술어.
    private static func testUsableFrame() {
        expectName("normal frame is usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: 0, y: 25, width: 800, height: 600)))", "true")
        expectName("zero width not usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: 0, y: 0, width: 0, height: 600)))", "false")
        expectName("negative width not usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: 0, y: 0, width: -10, height: 600)))", "false")
        expectName("NaN origin not usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: CGFloat.nan, y: 0, width: 800, height: 600)))", "false")
        expectName("infinite size not usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 600)))", "false")
    }

    // CommandGroup 표시명·토큰과 command→group 매핑 전수.
    private static func testCommandGroups() {
        expectName("core displayName", CommandGroup.core.displayName, "Maximize · Undo · Center")
        expectName("halves displayName", CommandGroup.halves.displayName, "Halves")
        expectName("thirds displayName", CommandGroup.thirds.displayName, "Thirds")
        expectName("twoThirds displayName", CommandGroup.twoThirds.displayName, "Two-Thirds")
        expectName("move displayName", CommandGroup.move.displayName, "Move")
        expectName("relative displayName", CommandGroup.relative.displayName, "Relative Resize")
        expectName("display displayName", CommandGroup.display.displayName, "Displays")
        expectName("core token", CommandGroup.core.token, "core")
        expectName("halves token", CommandGroup.halves.token, "halves")
        expectName("thirds token", CommandGroup.thirds.token, "thirds")
        expectName("twoThirds token", CommandGroup.twoThirds.token, "twoThirds")
        expectName("move token", CommandGroup.move.token, "move")
        expectName("relative token", CommandGroup.relative.token, "relative")
        expectName("display token", CommandGroup.display.token, "display")
        expectName("maximize→core", "\(WindowCommand.maximize.group == .core)", "true")
        expectName("maximizeGaps→core", "\(WindowCommand.maximizeGaps.group == .core)", "true")
        expectName("undo→core", "\(WindowCommand.undo.group == .core)", "true")
        expectName("move center→core", "\(WindowCommand.move(.center).group == .core)", "true")
        expectName("snapThrow→halves", "\(WindowCommand.snapThrow(.left).group == .halves)", "true")
        expectName("moveToDisplay→display", "\(WindowCommand.moveToDisplay(.top).group == .display)", "true")
        expectName("move→move", "\(WindowCommand.move(.left).group == .move)", "true")
        expectName("relativeHalf→relative", "\(WindowCommand.relativeHalf(.top).group == .relative)", "true")
        expectName("absolute half→halves", "\(absolute(.horizontal, .half, .first).group == .halves)", "true")
        expectName("absolute third→thirds", "\(absolute(.horizontal, .third, .first).group == .thirds)", "true")
        expectName("absolute twoThird→twoThirds", "\(absolute(.horizontal, .twoThird, .first).group == .twoThirds)", "true")
    }

    // CommandPrimitives 표시 문자열·심볼·토큰 전수(switch 모든 arm).
    private static func testPrimitiveStrings() {
        expectName("frac half symbol", Fraction.half.symbol, "1/2")
        expectName("frac third symbol", Fraction.third.symbol, "1/3")
        expectName("frac twoThird symbol", Fraction.twoThird.symbol, "2/3")
        expectName("frac half token", Fraction.half.token, "half")
        expectName("frac third token", Fraction.third.token, "third")
        expectName("frac twoThird token", Fraction.twoThird.token, "twoThird")
        expectName("abs left 1/2", absolute(.horizontal, .half, .first).displayName, "Left 1/2")
        expectName("abs center 1/3", absolute(.horizontal, .third, .center).displayName, "Center 1/3")
        expectName("abs right 1/2", absolute(.horizontal, .half, .last).displayName, "Right 1/2")
        expectName("abs top 1/2", absolute(.vertical, .half, .first).displayName, "Top 1/2")
        expectName("abs middle 1/3", absolute(.vertical, .third, .center).displayName, "Middle 1/3")
        expectName("abs bottom 1/2", absolute(.vertical, .half, .last).displayName, "Bottom 1/2")
        expectName("movedir left", MoveDirection.left.displayName, "Left")
        expectName("movedir right", MoveDirection.right.displayName, "Right")
        expectName("movedir up", MoveDirection.up.displayName, "Up")
        expectName("movedir down", MoveDirection.down.displayName, "Down")
        expectName("movedir center", MoveDirection.center.displayName, "Center")
        expectName("rel left", RelativeAnchor.left.displayName, "Left")
        expectName("rel right", RelativeAnchor.right.displayName, "Right")
        expectName("rel top", RelativeAnchor.top.displayName, "Top")
        expectName("rel bottom", RelativeAnchor.bottom.displayName, "Bottom")
        expectName("snap left name", SnapEdge.left.displayName, "Left 1/2")
        expectName("snap right name", SnapEdge.right.displayName, "Right 1/2")
        expectName("snap top name", SnapEdge.top.displayName, "Top 1/2")
        expectName("snap bottom name", SnapEdge.bottom.displayName, "Bottom 1/2")
        expectName("snap left dir", SnapEdge.left.displayDirection, "Left")
        expectName("snap right dir", SnapEdge.right.displayDirection, "Right")
        expectName("snap top dir", SnapEdge.top.displayDirection, "Up")
        expectName("snap bottom dir", SnapEdge.bottom.displayDirection, "Down")
    }

    private static func testCommandModel() {
        expectName("menuCommands count", "\(WindowCommand.menuCommands.count)", "34")
        expectName("maximize name", WindowCommand.maximize.displayName, "Maximize")
        expectName("maximizeGaps name", WindowCommand.maximizeGaps.displayName, "Maximize with Gaps")
        expectName("right 1/2 name", absolute(.horizontal, .half, .last).displayName, "Right 1/2")
        expectName("vertical middle 1/3 name", absolute(.vertical, .third, .center).displayName, "Middle 1/3")
        expectName("move name", WindowCommand.move(.left).displayName, "Move Left")
        expectName("relative name", WindowCommand.relativeHalf(.top).displayName, "Shrink Top 1/2")
        expectName("relative 2/3 name", WindowCommand.relativeTwoThird(.left).displayName, "Shrink Left 2/3")
        expectName("relative 2/3 in relative group", "\(WindowCommand.relativeTwoThird(.left).group == .relative)", "true")
        expectName("undo name", WindowCommand.undo.displayName, "Undo")
    }

    // helpText(Settings tooltip): 모든 명령이 비어있지 않아야 하고, 대표 계열 문구를 확인.
    private static func testCommandHelpText() {
        var allNonEmpty = true
        for command in WindowCommand.menuCommands where command.helpText.isEmpty { allNonEmpty = false }
        expectName("every command has non-empty helpText", "\(allNonEmpty)", "true")
        expectName("maximizeGaps helpText",
                   WindowCommand.maximizeGaps.helpText, "Fill the work area, leaving a uniform gap on all sides.")
        expectName("move center helpText",
                   WindowCommand.move(.center).helpText, "Center the window at its current size.")
        expectName("undo helpText", WindowCommand.undo.helpText, "Restore the window's previous frame.")
    }

    private static func testCommandIdentifiers() {
        let commands = WindowCommand.menuCommands
        var roundTripped = 0
        for command in commands where WindowCommand.command(forIdentifier: command.identifier) == command {
            roundTripped += 1
        }
        expectName("identifier round-trip count", "\(roundTripped)", "34")
        expectName("unique identifier count", "\(Set(commands.map { $0.identifier }).count)", "34")
        expectName("maximizeGaps identifier", WindowCommand.maximizeGaps.identifier, "maximizeGaps")
        expectName("absolute identifier", absolute(.horizontal, .third, .center).identifier,
                   "absolute.horizontal.third.center")
        expectName("move identifier", WindowCommand.move(.center).identifier, "move.center")
        expectName("relative identifier", WindowCommand.relativeHalf(.top).identifier, "relativeHalf.top")
        expectName("relative 2/3 identifier", WindowCommand.relativeTwoThird(.bottom).identifier,
                   "relativeTwoThird.bottom")
        expectName("undo identifier", WindowCommand.undo.identifier, "undo")
        expectName("unknown identifier is nil", "\(WindowCommand.command(forIdentifier: "nope") == nil)", "true")
    }
}
