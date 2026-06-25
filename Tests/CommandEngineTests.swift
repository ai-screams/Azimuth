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
        testSnapHalves()
        testDisplayMove()
        testCommandModel()
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
        let rightInRight = FrameCalculator.isWithinHalf(rightHalf, edge: .right, workArea: workArea)
        let leftInRight = FrameCalculator.isWithinHalf(leftHalf, edge: .right, workArea: workArea)
        let bottomInBottom = FrameCalculator.isWithinHalf(bottomHalf, edge: .bottom, workArea: workArea)
        expectName("right half within right", "\(rightInRight)", "true")
        expectName("left half not within right", "\(leftInRight)", "false")
        expectName("bottom half within bottom", "\(bottomInBottom)", "true")

        let from = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let to = CGRect(x: 2000, y: 0, width: 1000, height: 1000)
        expect("display move keeps left-half", display(CGRect(x: 0, y: 0, width: 500, height: 1000), from, to),
               CGRect(x: 2000, y: 0, width: 500, height: 1000))
        expect("display move keeps relative origin", display(CGRect(x: 250, y: 250, width: 500, height: 500), from, to),
               CGRect(x: 2250, y: 250, width: 500, height: 500))
        let small = CGRect(x: 100, y: 0, width: 600, height: 600)
        expect("display move caps into smaller", display(CGRect(x: 0, y: 0, width: 1000, height: 1000), from, small),
               CGRect(x: 100, y: 0, width: 600, height: 600))
        expectName("moveToDisplay name", WindowCommand.moveToDisplay(.top).displayName, "Move to Up Display")
    }

    private static func display(_ rect: CGRect, _ from: CGRect, _ to: CGRect) -> CGRect {
        FrameCalculator.displayMoveRect(rect, from: from, to: to)
    }

    private static func testCommandModel() {
        expectName("menuCommands count", "\(WindowCommand.menuCommands.count)", "29")
        expectName("maximize name", WindowCommand.maximize.displayName, "Maximize")
        expectName("right 1/2 name", absolute(.horizontal, .half, .last).displayName, "Right 1/2")
        expectName("vertical middle 1/3 name", absolute(.vertical, .third, .center).displayName, "Middle 1/3")
        expectName("move name", WindowCommand.move(.left).displayName, "Move Left")
        expectName("relative name", WindowCommand.relativeHalf(.top).displayName, "Shrink Top 1/2")
        expectName("undo name", WindowCommand.undo.displayName, "Undo")
    }

    private static func testCommandIdentifiers() {
        let commands = WindowCommand.menuCommands
        var roundTripped = 0
        for command in commands where WindowCommand.command(forIdentifier: command.identifier) == command {
            roundTripped += 1
        }
        expectName("identifier round-trip count", "\(roundTripped)", "29")
        expectName("unique identifier count", "\(Set(commands.map { $0.identifier }).count)", "29")
        expectName("absolute identifier", absolute(.horizontal, .third, .center).identifier,
                   "absolute.horizontal.third.center")
        expectName("move identifier", WindowCommand.move(.center).identifier, "move.center")
        expectName("relative identifier", WindowCommand.relativeHalf(.top).identifier, "relativeHalf.top")
        expectName("undo identifier", WindowCommand.undo.identifier, "undo")
        expectName("unknown identifier is nil", "\(WindowCommand.command(forIdentifier: "nope") == nil)", "true")
    }
}
