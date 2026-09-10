// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 명령 모델·그룹·식별자.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// ⚠️ AppKit/AX 비의존. 새 테스트 파일은 scripts/test.sh·coverage.sh 양쪽에 추가해야 한다.

import CoreGraphics
import Foundation

extension CommandEngineTests {

    // CommandGroup 표시명·토큰과 command→group 매핑 전수.
    static func testCommandGroups() {
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
    static func testPrimitiveStrings() {
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

    static func testCommandModel() {
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
    static func testCommandHelpText() {
        var allNonEmpty = true
        for command in WindowCommand.menuCommands where command.helpText.isEmpty { allNonEmpty = false }
        expectName("every command has non-empty helpText", "\(allNonEmpty)", "true")
        expectName("maximizeGaps helpText",
                   WindowCommand.maximizeGaps.helpText, "Fill the work area, leaving a uniform gap on all sides.")
        expectName("move center helpText",
                   WindowCommand.move(.center).helpText, "Center the window at its current size.")
        expectName("undo helpText", WindowCommand.undo.helpText, "Restore the window's previous frame.")
    }

    static func testCommandIdentifiers() {
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

    /// AX messaging timeout 정책의 불변식. `write`가 `resolve`보다 작아지면 WindowFrameWriter의
    /// 상향이 이름과 반대로 상한을 *내리는* 동작이 되어, 쓰기 타임아웃이 `.transient`(조용한 스킵)로
    /// 떨어지는 것을 막으려던 목적이 정확히 뒤집힌다. 컴파일 에러가 나지 않으므로 여기서 잡는다.
    static func testMessagingTimeoutPolicy() {
        expectName("write >= resolve", "\(AXMessagingTimeout.write >= AXMessagingTimeout.resolve)", "true")
        expectName("invariantHolds", "\(AXMessagingTimeout.invariantHolds)", "true")
        // 양수여야 한다 — AXUIElementSetMessagingTimeout은 0을 "전역 기본값(6초)으로 복귀"로 해석하고,
        // 음수는 kAXErrorIllegalArgument다. 둘 다 이 설계가 막으려는 것이다.
        expectName("resolve is positive", "\(AXMessagingTimeout.resolve > 0)", "true")
        expectName("write is positive", "\(AXMessagingTimeout.write > 0)", "true")
    }

    /// 고급 설정에서 온 값의 클램프. 저장된 defaults는 손으로 편집될 수 있어 신뢰하지 않는 입력이다.
    /// 특히 0은 AX가 "전역 기본값(6초) 복귀"로 해석하므로 반드시 걸러야 한다.
    static func testResolveTimeoutClamp() {
        let clamp = AXMessagingTimeout.clampedResolve
        expectName("0 falls back to default", "\(clamp(0))", "\(AXMessagingTimeout.resolve)")
        expectName("negative falls back", "\(clamp(-1))", "\(AXMessagingTimeout.resolve)")
        expectName("NaN falls back", "\(clamp(Float.nan))", "\(AXMessagingTimeout.resolve)")
        expectName("infinity falls back", "\(clamp(Float.infinity))", "\(AXMessagingTimeout.resolve)")
        expectName("below floor clamps up", "\(clamp(0.01))", "\(AXMessagingTimeout.minResolve)")
        expectName("above write clamps down", "\(clamp(99))", "\(AXMessagingTimeout.write)")
        expectName("in-range passes through", "\(clamp(0.75))", "0.75")
        // 클램프 결과는 언제나 쓰기 상한 이하여야 한다 — 넘으면 상향이 상한을 내리는 동작이 된다.
        let violations = [Float(-5), 0, 0.01, 0.25, 0.5, 1, 2, 99, .nan].filter { clamp($0) > AXMessagingTimeout.write }
        expectName("clamp never exceeds write", "\(violations.count)", "0")
    }

    /// 선택지의 값과 문구가 같이 움직이는지, 임의의 저장값에서도 팝업이 하나를 고르는지.
    static func testResolveTimeoutChoices() {
        expectName("choice count", "\(ResolveTimeoutChoice.allCases.count)", "3")
        expectName("default is balanced", ResolveTimeoutChoice.default.rawValue, "balanced")
        expectName("default seconds match resolve",
                   "\(ResolveTimeoutChoice.default.seconds)", "\(AXMessagingTimeout.resolve)")
        // 모든 선택지가 클램프를 통과해야 한다 — 통과 못 하면 UI가 고를 수 없는 값을 보여주는 것이다.
        let unclampable = ResolveTimeoutChoice.allCases.filter { AXMessagingTimeout.clampedResolve($0.seconds) != $0.seconds }
        expectName("every choice survives clamp", "\(unclampable.count)", "0")
        expectName("nearest to 0.3 is quick", ResolveTimeoutChoice.nearest(toSeconds: 0.3).rawValue, "quick")
        expectName("nearest to 5 is patient", ResolveTimeoutChoice.nearest(toSeconds: 5).rawValue, "patient")
        expectName("titles are unique",
                   "\(Set(ResolveTimeoutChoice.allCases.map { $0.title }).count)", "3")
    }
}
