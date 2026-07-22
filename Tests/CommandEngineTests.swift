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
        testSnapDecision()
        testCenterClamp()
        testAnchorOrigin()
        testAnchoredOrigin()
        testFallbackCommands()
        testGapMaximize()
        testGapMaximizeDegenerate()
        testDisplayGeometry()
        testIsConstrained()
        testUsableFrame()
        testFrameApply()
        testOutcomePolicy()
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

    private static func expectDecision(_ label: String, _ got: OutcomeDecision, _ want: OutcomeDecision) {
        checks += 1
        if got != want {
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
        expectName("opposite right", SnapEdge.right.opposite.token, "left")
        expectName("opposite top", SnapEdge.top.opposite.token, "bottom")
        expectName("opposite bottom", SnapEdge.bottom.opposite.token, "top")
        expectName("snap left name", WindowCommand.snapThrow(.left).displayName, "Left 1/2")
    }

    private static func testDisplayMove() {
        let from = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let to = CGRect(x: 2000, y: 0, width: 1000, height: 1000)
        expect("display move keeps left-half", display(CGRect(x: 0, y: 0, width: 500, height: 1000), from, to),
               CGRect(x: 2000, y: 0, width: 500, height: 1000))
        expect("display move keeps relative origin", display(CGRect(x: 250, y: 250, width: 500, height: 500), from, to),
               CGRect(x: 2250, y: 250, width: 500, height: 500))
        let small = CGRect(x: 100, y: 0, width: 600, height: 600)
        expect("display move caps into smaller", display(CGRect(x: 0, y: 0, width: 1000, height: 1000), from, small),
               CGRect(x: 100, y: 0, width: 600, height: 600))
        // 절대 크기 유지 — 대상 화면 크기가 달라도 창이 들어가기만 하면 픽셀 크기를 보존한다
        // (화면 점유 비율로 축소하지 않음). 비례였다면 200×200이 됐을 창이 400×400을 유지한다.
        let big = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        let smallDest = CGRect(x: 5000, y: 0, width: 1000, height: 1000)
        expect("display move preserves absolute size (no proportional shrink)",
               display(CGRect(x: 0, y: 0, width: 400, height: 400), big, smallDest),
               CGRect(x: 5000, y: 0, width: 400, height: 400))
        // 대상 화면에 안 들어가면 두 축을 같은 배율로 줄인다 — 종횡비가 보존된다(감사 M-1).
        // 축별로 캡하면 1500×800이 1000×800(15:8 → 10:8)으로 찌그러졌다.
        expect("oversize window shrinks uniformly, keeping aspect ratio",
               display(CGRect(x: 0, y: 0, width: 1500, height: 800), big, smallDest),
               CGRect(x: 5000, y: 0, width: 1000, height: 800 * (1000.0 / 1500.0)))
        expect("16:9 window stays 16:9 when it must shrink",
               display(CGRect(x: 0, y: 0, width: 1600, height: 900), big, smallDest),
               CGRect(x: 5000, y: 0, width: 1000, height: 562.5))

        // 위치는 "창이 실제로 움직일 수 있는 범위"(작업영역 − 창 크기)로 정규화한다(감사 M-1).
        // 화면 전체 크기로 나누면 해상도가 다른 화면에서 중앙 창이 중앙을 벗어난다.
        let wide = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let narrow = CGRect(x: 2000, y: 0, width: 1440, height: 900)
        // 1920 화면 정중앙의 960 폭 창(x=480) → 1440 화면에서도 정중앙(x=2000+240).
        // 화면 폭으로 나누던 옛 공식은 x=2360으로 120pt 오른쪽에 놓았다.
        expect("centered window stays centered across resolutions",
               display(CGRect(x: 480, y: 270, width: 960, height: 540), wide, narrow),
               CGRect(x: 2240, y: 180, width: 960, height: 540))
        // 가장자리는 옛 공식도 clamp 덕에 같은 값이었다 — 회귀 방지로 고정한다.
        expect("right-edge window stays on the right edge",
               display(CGRect(x: 960, y: 270, width: 960, height: 540), wide, narrow),
               CGRect(x: 2480, y: 180, width: 960, height: 540))
        expect("left-edge window stays on the left edge",
               display(CGRect(x: 0, y: 0, width: 960, height: 540), wide, narrow),
               CGRect(x: 2000, y: 0, width: 960, height: 540))
        // 작업영역을 꽉 채운 창은 움직일 여지가 0 → 목적지 원점에 붙는다(0으로 나누지 않는다).
        expect("full-width window pins to the destination origin",
               display(CGRect(x: 0, y: 0, width: 1920, height: 1080), wide, narrow),
               CGRect(x: 2000, y: 0, width: 1440, height: 810))
        expectName("moveToDisplay name", WindowCommand.moveToDisplay(.top).displayName, "Move to Up Display")
    }

    private static func display(_ rect: CGRect, _ from: CGRect, _ to: CGRect) -> CGRect {
        FrameCalculator.displayMoveRect(rect, from: from, to: to)
    }

    // H-2: snapThrow의 "이미 스냅됨 → 던지기" 판정. 엄격 기하 OR Azimuth의 스냅 기록으로만 인정한다.
    private static func testSnapDecision() {
        let leftHalf = FrameCalculator.halfRect(.left, workArea: workArea) // (0,25,960,1055)
        let rightHalf = FrameCalculator.halfRect(.right, workArea: workArea)
        // ① 정확히 그 방향 절반 → 스냅됨(엄격 기하, 기록 없이도).
        expectName("exact left half is snapped (geometric)",
                   "\(FrameCalculator.isAlreadySnapped(current: leftHalf, edge: .left, workArea: workArea, recorded: nil))",
                   "true")
        expectName("exact right half is snapped (geometric)",
                   "\(FrameCalculator.isAlreadySnapped(current: rightHalf, edge: .right, workArea: workArea, recorded: nil))",
                   "true")
        // 수동으로 좁게 둔 세로 창(폭 200) → 스냅 아님 → 첫 입력에 던져지지 않고 스냅(감사 H-2 핵심).
        let narrowLeft = CGRect(x: 0, y: 25, width: 200, height: 1055)
        expectName("manually narrow flush-left window is NOT snapped",
                   "\(FrameCalculator.isAlreadySnapped(current: narrowLeft, edge: .left, workArea: workArea, recorded: nil))",
                   "false")
        // 화면 왼쪽 밖으로 나간 창 → 스냅 아님(과거엔 flush로 오판했음).
        let offScreen = CGRect(x: -2000, y: 25, width: 200, height: 1055)
        expectName("off-screen window is NOT snapped",
                   "\(FrameCalculator.isAlreadySnapped(current: offScreen, edge: .left, workArea: workArea, recorded: nil))",
                   "false")
        // ② Azimuth가 스냅한 제약 앱(정확한 반쪽 미달)이 그 frame 그대로면 known-snap → 스냅됨.
        let constrained = CGRect(x: 0, y: 25, width: 700, height: 1055)
        let record = SnapRecord(edge: .left, frame: constrained)
        expectName("recorded constrained snap (unchanged) is snapped",
                   "\(FrameCalculator.isAlreadySnapped(current: constrained, edge: .left, workArea: workArea, recorded: record))",
                   "true")
        // 기록됐지만 외부에서 움직임(현재≠기록) → 무효화 → 스냅 아님.
        let moved = CGRect(x: 300, y: 25, width: 700, height: 1055)
        expectName("recorded snap but externally moved is NOT snapped",
                   "\(FrameCalculator.isAlreadySnapped(current: moved, edge: .left, workArea: workArea, recorded: record))",
                   "false")
        // 기록된 edge가 다른 방향이면 그 방향엔 스냅 아님.
        expectName("recorded left snap does not count as right snap",
                   "\(FrameCalculator.isAlreadySnapped(current: constrained, edge: .right, workArea: workArea, recorded: record))",
                   "false")
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

    // M-4: 명시적 anchor로 실제 크기에 맞춰 고정 모서리를 유지(앱 반올림에 의한 드리프트 방지).
    private static func testAnchoredOrigin() {
        let target = CGRect(x: 400, y: 100, width: 400, height: 300) // maxX=800, maxY=400
        // 앱이 요청(400)보다 작게(396) 잡아도 오른쪽 모서리(800) 유지 → x=404. (기존 코드가 못 잡던 드리프트)
        expectPoint("right anchor keeps right edge when app rounds down",
                    FrameCalculator.anchoredOrigin(anchor: .right, actualSize: CGSize(width: 396, height: 300),
                                                   target: target, workArea: workArea),
                    CGPoint(x: 404, y: 100))
        // 앱이 요청보다 크게(420) 잡아도 오른쪽 모서리 유지 → x=380.
        expectPoint("right anchor keeps right edge when app overshoots",
                    FrameCalculator.anchoredOrigin(anchor: .right, actualSize: CGSize(width: 420, height: 300),
                                                   target: target, workArea: workArea),
                    CGPoint(x: 380, y: 100))
        // 하단 anchor: maxY(400) 고정, 실제 높이 290 → y=110.
        expectPoint("bottom anchor keeps bottom edge",
                    FrameCalculator.anchoredOrigin(anchor: .bottom, actualSize: CGSize(width: 400, height: 290),
                                                   target: target, workArea: workArea),
                    CGPoint(x: 400, y: 110))
        // topLeft: 크기가 달라도 origin 그대로.
        expectPoint("topLeft anchor keeps origin",
                    FrameCalculator.anchoredOrigin(anchor: .topLeft, actualSize: CGSize(width: 396, height: 290),
                                                   target: target, workArea: workArea),
                    CGPoint(x: 400, y: 100))
        // 최소폭이 큰 제약 앱을 화면 왼쪽 근처에서 우측 앵커로 축소해도 작업영역 밖으로 밀리지 않는다.
        // (회귀 방지: 클램프가 없으면 maxX=350·실제폭 800에서 x=-450으로 화면 밖에 놓였다.)
        expectPoint("right anchor clamps into the work area (constrained app near left edge)",
                    FrameCalculator.anchoredOrigin(anchor: .right, actualSize: CGSize(width: 800, height: 600),
                                                   target: CGRect(x: 200, y: 200, width: 150, height: 600),
                                                   workArea: workArea),
                    CGPoint(x: 0, y: 200))
        expectPoint("bottom anchor clamps into the work area",
                    FrameCalculator.anchoredOrigin(anchor: .bottom, actualSize: CGSize(width: 400, height: 2000),
                                                   target: CGRect(x: 100, y: 200, width: 400, height: 300),
                                                   workArea: workArea),
                    CGPoint(x: 100, y: 25))
        // 앱이 비정상 크기(NaN)를 보고하면 앵커 보정을 포기하고 목표 origin — NaN이 AX 쓰기로 새지 않게.
        expectPoint("non-finite actual size falls back to target origin",
                    FrameCalculator.anchoredOrigin(anchor: .right,
                                                   actualSize: CGSize(width: CGFloat.nan, height: 600),
                                                   target: CGRect(x: 400, y: 100, width: 400, height: 300),
                                                   workArea: workArea),
                    CGPoint(x: 400, y: 100))
        // workAreaEdges: 기존 작업영역 모서리 추론 경로로 위임.
        let rightHalf = FrameCalculator.halfRect(.right, workArea: workArea)
        expectPoint("workAreaEdges delegates to edge inference",
                    FrameCalculator.anchoredOrigin(anchor: .workAreaEdges,
                                                   actualSize: CGSize(width: 1100, height: 1055),
                                                   target: rightHalf, workArea: workArea),
                    CGPoint(x: 820, y: 25))
        // 명령 → anchor 의도 매핑.
        expectName("relative right maps to right anchor",
                   "\(WindowCommand.relativeHalf(.right).frameAnchor == FrameAnchor.right)", "true")
        expectName("relative bottom maps to bottom anchor",
                   "\(WindowCommand.relativeTwoThird(.bottom).frameAnchor == FrameAnchor.bottom)", "true")
        expectName("relative left maps to topLeft anchor",
                   "\(WindowCommand.relativeHalf(.left).frameAnchor == FrameAnchor.topLeft)", "true")
        expectName("relative top maps to topLeft anchor",
                   "\(WindowCommand.relativeTwoThird(.top).frameAnchor == FrameAnchor.topLeft)", "true")
        expectName("undo maps to topLeft anchor",
                   "\(WindowCommand.undo.frameAnchor == FrameAnchor.topLeft)", "true")
        expectName("maximize maps to workAreaEdges anchor",
                   "\(WindowCommand.maximize.frameAnchor == FrameAnchor.workAreaEdges)", "true")
        expectName("snapThrow maps to workAreaEdges anchor",
                   "\(WindowCommand.snapThrow(.left).frameAnchor == FrameAnchor.workAreaEdges)", "true")
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
        // 순서 의존성 회귀 방지: perpendicular gap이 여러 단계로 놓여도 항상 "최소"를 고른다.
        // 비교에 데드밴드를 쓰면 순차 비교가 비추이적이 되어(각 단계가 직전 승자와만 비교)
        // [1.2, 0.8, 0.4, 0.0]에서 최소가 아닌 0.4가 뽑히고, 순서를 뒤집으면 결과가 달라졌다.
        let seamWin = CGRect(x: 100, y: 495, width: 10, height: 10) // midY = 500
        let ladder = [
            CGRect(x: -500, y: 501.2, width: 500, height: 400), // gap 1.2
            CGRect(x: -500, y: 500.8, width: 500, height: 400), // gap 0.8
            CGRect(x: -500, y: 500.4, width: 500, height: 400), // gap 0.4
            CGRect(x: -500, y: 500.0, width: 500, height: 400) // gap 0.0
        ]
        expectName("perpendicular ladder picks the true minimum (idx3)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: ladder, window: seamWin, edge: .left) ?? -1)",
                   "3")
        expectName("reversed ladder picks the same screen (idx0)",
                   "\(DisplayGeometry.selectAdjacentIndex(current: cur, candidates: Array(ladder.reversed()), window: seamWin, edge: .left) ?? -1)",
                   "0")
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

    // H-1: 적용 결과 판정 순수 함수 — Undo는 achieved가 pre에서 변했는지, 도달은 target 기준.
    private static func testFrameApply() {
        let pre = CGRect(x: 0, y: 25, width: 800, height: 600)
        // 변화 없음(무시된 쓰기) → Undo 미기록.
        expectName("unchanged frame is not undo-worthy",
                   "\(FrameApply.changed(pre: pre, achieved: pre))", "false")
        // 쓰기 임계(changeEpsilon 0.5pt) 이하의 미세 차이만 "변화 없음" — AX 왕복 반올림 잡음 흡수.
        expectName("sub-epsilon jitter is not changed",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 0.3, y: 25.2, width: 800.4, height: 600)))",
                   "false")
        // 회귀 방지: 쓰기가 일어날 만큼(>0.5pt) 달라졌으면 반드시 "변함"이어야 한다. 과거엔 size 8pt
        // 허용오차를 써서 5pt 축소가 "변화 없음"이 되어 undo가 기록되지 않았고, 그 결과 직전 명령의
        // undo 항목이 남아 Undo 시 창이 한참 전 frame으로 튀었다.
        expectName("5pt resize is changed (undo must be recorded)",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 0, y: 25, width: 795, height: 600)))", "true")
        expectName("1pt move is changed (undo must be recorded)",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 1, y: 25, width: 800, height: 600)))", "true")
        // 불변식: "쓴다"(movesOrigin/resizesSize)와 "변했다"(changed)는 같은 임계를 써야 한다.
        // 상대 축소 100pt 하한에 걸리는 실제 케이스로 고정한다(105 → 100).
        let beforeFloor = CGRect(x: 300, y: 200, width: 105, height: 600)
        let floored = CGRect(x: 300, y: 200, width: 100, height: 600)
        expectName("write-decision and changed agree at the 100pt floor",
                   "\(FrameApply.resizesSize(from: beforeFloor, to: floored) == FrameApply.changed(pre: beforeFloor, achieved: floored))",
                   "true")
        // 위치만 바뀜(부분 적용) → 변화로 인정 → Undo 기록.
        expectName("position-only move is changed",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 400, y: 25, width: 800, height: 600)))", "true")
        // 크기만 바뀜(size 축 8pt 초과) → 변화.
        expectName("size-only change beyond tolerance is changed",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 0, y: 25, width: 900, height: 600)))", "true")
        // 목표 도달: target과 achieved가 허용오차 내(제약 앱 셀 오차 포함).
        let target = CGRect(x: 960, y: 25, width: 960, height: 1055)
        expectName("reached target within tolerance",
                   "\(FrameApply.reached(target: target, achieved: CGRect(x: 961, y: 26, width: 955, height: 1055)))", "true")
        // 제약 앱: 크기가 목표보다 8pt 넘게 크면 미도달.
        expectName("constrained size beyond tolerance not reached",
                   "\(FrameApply.reached(target: target, achieved: CGRect(x: 960, y: 25, width: 1100, height: 1055)))", "false")
        // M-3: 축별 변경 판정(해당 축만 쓰고 권한을 요구하도록).
        let base = CGRect(x: 100, y: 100, width: 400, height: 300)
        let moved = CGRect(x: 200, y: 100, width: 400, height: 300)
        let resized = CGRect(x: 100, y: 100, width: 600, height: 300)
        expectName("move-only changes origin", "\(FrameApply.movesOrigin(from: base, to: moved))", "true")
        expectName("move-only does not resize", "\(FrameApply.resizesSize(from: base, to: moved))", "false")
        expectName("resize-only changes size", "\(FrameApply.resizesSize(from: base, to: resized))", "true")
        expectName("resize-only does not move", "\(FrameApply.movesOrigin(from: base, to: resized))", "false")
        expectName("identical frame neither moves nor resizes",
                   "\(FrameApply.movesOrigin(from: base, to: base) || FrameApply.resizesSize(from: base, to: base))", "false")
    }

    // 결과 커밋 정책 — AX 없이 부분 실패/읽기 실패 조합에서 Undo·Snap 상태를 어떻게 커밋하는지.
    // 이 조합들이 자동 검증 밖에 있었다(감사 H-2/H-3).
    private static func testOutcomePolicy() {
        let pre = CGRect(x: 0, y: 25, width: 960, height: 1055)
        let moved = CGRect(x: 960, y: 25, width: 960, height: 1055)
        // 부분 적용: position은 반영되고 size 쓰기는 실패해 목표 절반에 못 미친 frame.
        let partial = CGRect(x: 960, y: 25, width: 700, height: 1055)

        struct Outcome {
            var target: CGRect
            var achieved: CGRect?
            var failed = false
            var mutated = false
            var edge: SnapEdge?
        }
        func decide(_ outcome: Outcome) -> OutcomeDecision {
            CommandOutcomePolicy.decide(CommandOutcome(
                pre: pre, target: outcome.target, achieved: outcome.achieved,
                failed: outcome.failed, mayHaveMutated: outcome.mutated, snappedEdge: outcome.edge
            ))
        }

        // 성공 스냅: 복원점과 스냅 상태를 함께 커밋한다(기존 동작 유지).
        expectDecision("successful snap records undo and snap state",
                       decide(Outcome(target: moved, achieved: moved, mutated: true, edge: .right)),
                       OutcomeDecision(recordUndo: true, snap: .record(.right, frame: moved)))
        // ① 의도된 no-op — 인접 디스플레이 없는 snapThrow는 target이 곧 현재 frame이다. 창은
        // 그대로지만 여전히 그 edge에 스냅돼 있으므로, undo는 덮지 않고 스냅 상태만 갱신한다.
        expectDecision("intended no-op (target == pre) refreshes snap state",
                       decide(Outcome(target: pre, achieved: pre, edge: .left)),
                       OutcomeDecision(recordUndo: false, snap: .record(.left, frame: pre)))
        // ② 무시된 쓰기 — target이 달랐는데 AX가 .success를 돌려주고도 창이 안 움직였다.
        // ①과 결과(achieved == pre)는 같지만 이 창은 스냅된 적이 없다. 여기서 기록하면 다음
        // 같은 방향 입력이 "이미 스냅됨"으로 오판해 창을 인접 디스플레이로 던진다.
        expectDecision("successful-but-ignored write must not commit snap state",
                       decide(Outcome(target: moved, achieved: pre, mutated: true, edge: .right)),
                       OutcomeDecision(recordUndo: false, snap: .keep))
        // 핵심(H-2): position만 적용되고 size가 실패한 부분 frame을 "스냅 완료"로 커밋하면,
        // 다음 같은 방향 입력이 창을 스냅된 것으로 오판해 다른 디스플레이로 던진다.
        expectDecision("partially applied snap must not commit snap state",
                       decide(Outcome(target: moved, achieved: partial, failed: true, mutated: true, edge: .right)),
                       OutcomeDecision(recordUndo: true, snap: .clear))
        // transient 실패(Space 전환 등)로 창이 전혀 안 움직였으면 기존 스냅 상태는 아직 유효하다.
        expectDecision("failed no-op keeps existing snap state",
                       decide(Outcome(target: moved, achieved: pre, failed: true, edge: .right)),
                       OutcomeDecision(recordUndo: false, snap: .keep))
        // 핵심(H-2): 쓰기는 반영됐는데 최종 read가 실패하면 결과를 모른다. 복원점을 남기지 않으면
        // 직전 명령의 undo 항목이 살아남아 Undo 시 창이 한참 전 frame으로 튄다 → 보수적으로 기록.
        expectDecision("write succeeded but final read failed still leaves a restore point",
                       decide(Outcome(target: moved, achieved: nil, failed: true, mutated: true, edge: .right)),
                       OutcomeDecision(recordUndo: true, snap: .clear))
        // 쓰기 자체가 안 먹었고 read도 실패 → 창이 변했다고 볼 근거가 없다. 아무것도 건드리지 않는다.
        expectDecision("no write and no read leaves both stores untouched",
                       decide(Outcome(target: moved, achieved: nil, failed: true, edge: .right)),
                       OutcomeDecision(recordUndo: false, snap: .keep))
        // 스냅이 아닌 일반 명령(maximize 등)은 스냅 상태를 건드리지 않는다.
        expectDecision("non-snap command does not touch snap state",
                       decide(Outcome(target: moved, achieved: moved, mutated: true)),
                       OutcomeDecision(recordUndo: true, snap: .keep))
        // 일반 명령이 부분 적용되면 창은 더 이상 기록된 스냅 frame이 아니다 → 상태를 버린다.
        expectDecision("partially applied non-snap command clears stale snap state",
                       decide(Outcome(target: moved, achieved: partial, failed: true, mutated: true)),
                       OutcomeDecision(recordUndo: true, snap: .clear))
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
