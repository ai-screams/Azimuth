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

    /// 해석 단계 예산은 사용자가 고른 상한에 비례해야 한다. 고정 3초이던 시절에는 Patient(1.0초)를
    /// 고른 사용자가 해석에 성공하고도 예산에 걸려 **조용히** 버려졌다 — "느린 앱을 기다리겠다"는
    /// 선택이 침묵 실패를 늘리는 뒤집힌 인센티브였다.
    static func testResolveBudget() {
        let budget = AXMessagingTimeout.resolveBudget
        // 기본값에서 이전 하드코딩 상수(3초)와 정확히 같다 = Balanced 사용자 동작 변화 0.
        // 이 등식이 깨지면 기본 사용자에게 조용한 동작 변화가 생긴 것이므로 반드시 실패해야 한다.
        expectName("balanced == previous constant", "\(budget(AXMessagingTimeout.resolve))", "3.0")
        // Quick 은 바닥값에 걸린다. 순수 비례면 1.5초인데, 이전 예산(3초)보다 짧아지면
        // 이전에 성공하던 명령이 실패하게 된다 — 버그 수정이 새 실패 모드를 들이지 않게 한다.
        expectName("quick clamps to legacy floor", "\(budget(AXMessagingTimeout.minResolve))", "3.0")
        expectName("floor equals previous constant", "\(AXMessagingTimeout.legacyResolveBudget)", "3.0")
        // 바닥 덕분에 Quick 에서는 8회 경로의 구조적 최대치로도 예산에 도달할 수 없다(= 이전과 같다).
        let quickCeiling = TimeInterval(8) * TimeInterval(AXMessagingTimeout.minResolve)
        expectName("quick stays unreachable", "\(quickCeiling < budget(AXMessagingTimeout.minResolve))", "true")
        expectName("patient", "\(budget(1.0))", "6.0")
        // 손편집 defaults가 클램프 상한까지 올려도 비례가 유지된다.
        expectName("hand-edited upper bound", "\(budget(AXMessagingTimeout.write))", "12.0")
        expectName("read count is 6", "\(AXMessagingTimeout.resolveReadCount)", "6")
        // Balanced 이상에서는 예산이 8회 경로의 구조적 최대치보다 **작아야** 한다. 같거나 크면
        // 그 설정에서 검사가 안 걸린다. 이 부등식이 readCount 의 상한을 고정한다.
        let eightReadCeiling = TimeInterval(8) * TimeInterval(AXMessagingTimeout.resolve)
        expectName("budget below 8-read ceiling", "\(budget(AXMessagingTimeout.resolve) < eightReadCeiling)", "true")
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

    /// 검색·접힘 상호작용. 이 판정이 틀리면 "검색했는데 결과가 접혀서 안 보인다"가 된다.
    static func testShortcutListPolicy() {
        let all = CommandGroup.allCases
        // 검색 없음: 헤더는 다 보이고, 펼침은 expanded 집합만 따른다.
        let idle = ShortcutListPolicy.display(
            matchedCounts: Dictionary(uniqueKeysWithValues: all.map { ($0, 1) }),
            isSearching: false,
            expanded: [.halves]
        )
        expectName("idle: halves expanded", "\(idle[.halves]?.isExpanded == true)", "true")
        expectName("idle: thirds collapsed", "\(idle[.thirds]?.isExpanded == false)", "true")
        expectName("idle: header visible", "\(idle[.thirds]?.isHeaderVisible == true)", "true")

        // 검색 중: 매칭된 그룹만 보이고 자동으로 펼쳐진다(expanded 집합과 무관).
        let searching = ShortcutListPolicy.display(
            matchedCounts: [.halves: 2, .thirds: 0],
            isSearching: true,
            expanded: []
        )
        expectName("search: matched auto-expands", "\(searching[.halves]?.isExpanded == true)", "true")
        expectName("search: matched header shown", "\(searching[.halves]?.isHeaderVisible == true)", "true")
        expectName("search: unmatched hidden", "\(searching[.thirds]?.isHeaderVisible == false)", "true")
        expectName("search: unmatched not expanded", "\(searching[.thirds]?.isExpanded == false)", "true")

        // 구분선은 "보이는 그룹들 사이"에만. 첫 보이는 그룹 위에는 없다.
        let firstVisible = all.first { searching[$0]?.isHeaderVisible == true }
        expectName("first visible has no separator",
                   "\(searching[firstVisible ?? .core]?.isSeparatorVisible == false)", "true")

        // 구분선 양성 분기: 보이는 그룹 사이에 숨은 그룹이 끼어도 다음 보이는 그룹에 구분선이 붙는다.
        // (CommandGroup 순서: core, halves, thirds, twoThirds, move, relative, display)
        let separated = ShortcutListPolicy.display(
            matchedCounts: [.thirds: 1, .relative: 1],
            isSearching: true,
            expanded: []
        )
        let actual = [separated[.thirds], separated[.twoThirds], separated[.relative]]
        let expected: [ShortcutGroupDisplay?] = [
            ShortcutGroupDisplay(isHeaderVisible: true, isExpanded: true, isSeparatorVisible: false),
            ShortcutGroupDisplay(isHeaderVisible: false, isExpanded: false, isSeparatorVisible: false),
            ShortcutGroupDisplay(isHeaderVisible: true, isExpanded: true, isSeparatorVisible: true)
        ]
        expectName("separators only between visible groups", "\(actual == expected)", "true")

        // 매칭 0건이면 아무 헤더도 보이지 않는다(빈 결과 라벨은 뷰가 처리).
        let none = ShortcutListPolicy.display(
            matchedCounts: Dictionary(uniqueKeysWithValues: all.map { ($0, 0) }),
            isSearching: true,
            expanded: [.halves]
        )
        expectName("no match: nothing visible", "\(none.values.filter { $0.isHeaderVisible }.count)", "0")

        // matches: 명령명과 그룹명 양쪽에 걸린다(기존 applyFilter 동작 유지).
        let leftHalf = WindowCommand.snapThrow(.left)
        expectName("matches command name", "\(ShortcutListPolicy.matches(query: "left", command: leftHalf))", "true")
        expectName("matches group name", "\(ShortcutListPolicy.matches(query: "halves", command: leftHalf))", "true")
        expectName("empty query matches all", "\(ShortcutListPolicy.matches(query: "  ", command: leftHalf))", "true")
        expectName("no match", "\(ShortcutListPolicy.matches(query: "zzz", command: leftHalf))", "false")
    }

    /// 실패 피드백 결정. 관측 가능한 결과 다섯(마지막 실패 표시·침묵·비프·알림·권한 안내)이
    /// 한 분기에 묶여 있어 테스트가 닿지 못하던 것을 순수 정책으로 뺐다.
    static func testCommandFeedbackPolicy() {
        let decide = CommandFeedbackPolicy.decide
        // 성공: 지난 실패 사유를 지운다.
        let ok = decide(nil, true, true, false)
        expectName("success clears", "\(ok.lastFailure)", "clear")
        expectName("success is quiet", "\(ok.beep || ok.notify || ok.nudgeForPermission)", "false")

        // .transient: 완전 침묵 + 지난 사유를 **유지**한다. 아무것도 성공하지 않았는데 지우면
        // 일어나지 않은 성공을 주장하는 셈이다.
        let transient = decide(.transient, true, true, false)
        expectName("transient keeps", "\(transient.lastFailure)", "keep")
        expectName("transient is silent", "\(transient.beep || transient.notify)", "false")
        expectName("transient never nudges", "\(transient.nudgeForPermission)", "false")

        // 권한 거부: 유일한 안내 트리거. 세션당 1회.
        let denied = decide(.resolution(.permissionDenied), true, true, false)
        expectName("permission denied nudges", "\(denied.nudgeForPermission)", "true")
        let deniedAgain = decide(.resolution(.permissionDenied), true, true, true)
        expectName("nudges once per session", "\(deniedAgain.nudgeForPermission)", "false")
        expectName("denied still reports", "\(deniedAgain.beep)", "true")

        // 다른 실패는 안내하지 않는다 — 창의 성질이지 권한 문제가 아니다.
        for error in [WindowCommandError.notMovable, .notResizable, .applyFailed,
                      .workAreaUnavailable, .noUndoState, .resolveBudgetExceeded,
                      .resolution(.noFocusedWindow)] {
            expectName("no nudge for \(error)", "\(decide(error, true, true, false).nudgeForPermission)", "false")
            // 문자열 설명 대신 값으로 비교한다 — enum 설명은 어포스트로피를 이스케이프해 비교가 깨진다.
            let reported = decide(error, true, true, false).lastFailure == .set(message: error.userFacingMessage)
            expectName("reports \(error)", "\(reported)", "true")
        }

        // 느린 앱(예산 초과)은 .transient 와 달리 재현되는 상태다 — 조용히 넘기지 않고 보고한다.
        let budget = decide(.resolveBudgetExceeded, true, true, false)
        expectName("budget exceeded is reported, not kept", "\(budget.lastFailure == .keep)", "false")
        expectName("budget exceeded beeps", "\(budget.beep)", "true")

        // 사운드·알림 토글은 각각 독립적으로 듣는다.
        expectName("sound off silences beep", "\(decide(.applyFailed, false, true, false).beep)", "false")
        expectName("sound off keeps notify", "\(decide(.applyFailed, false, true, false).notify)", "true")
        expectName("notify off keeps beep", "\(decide(.applyFailed, true, false, false).beep)", "true")
        expectName("notify off silences notify", "\(decide(.applyFailed, true, false, false).notify)", "false")
        // 토글은 안내에 영향을 주지 않는다 — 권한 안내는 피드백 설정과 독립이다.
        expectName("toggles do not gate nudge",
                   "\(decide(.resolution(.permissionDenied), false, false, false).nudgeForPermission)", "true")
    }

    /// 사용자에게 그대로 노출되는 문자열. 비어 있거나 중복이면 상태바 메뉴·알림이 쓸모없어진다.
    /// 정책 진리표만으로는 이 분기들이 실행되지 않으므로 전수로 확인한다.
    static func testUserFacingMessages() {
        let resolutions: [WindowResolutionError] = [
            .permissionDenied, .noFrontmostApplication, .noFocusedWindow, .fullscreenWindow,
            .unsupportedWindowType(subrole: "AXSheet"),
            .unsupportedWindowType(subrole: nil),   // subrole 을 못 읽은 창 — 별도 문구 분기
            .invalidFrame,
            .appUnresponsive(code: -25204), .axError(code: -25200),
            .messagingTimeoutConfigurationFailed(code: -25200)
        ]
        for error in resolutions {
            expectName("resolution message non-empty \(error)", "\(!error.userFacingMessage.isEmpty)", "true")
        }
        let commands: [WindowCommandError] = [
            .resolution(.permissionDenied), .workAreaUnavailable, .notMovable, .notResizable,
            .applyFailed, .transient, .noUndoState, .resolveBudgetExceeded
        ]
        for error in commands {
            expectName("command message non-empty \(error)", "\(!error.userFacingMessage.isEmpty)", "true")
        }
        // 서로 구별되어야 한다 — 같은 문구가 둘이면 사용자가 원인을 좁힐 수 없다.
        let messages = Set(commands.map(\.userFacingMessage))
        expectName("command messages are distinct", "\(messages.count)", "\(commands.count)")
    }

    /// `Result.commandError` — 피드백 정책의 입력을 만드는 어댑터. 성공값을 버리고 에러만 남긴다.
    static func testResultCommandError() {
        let success: Result<CGRect, WindowCommandError> = .success(CGRect(x: 1, y: 2, width: 3, height: 4))
        expectName("success has no error", "\(success.commandError == nil)", "true")
        let failure: Result<CGRect, WindowCommandError> = .failure(.notMovable)
        expectName("failure yields error", "\(failure.commandError == .notMovable)", "true")
    }

    /// `WindowFrame`은 AX 좌표의 origin+size를 한 값으로 나른다. `rect` 합성이 어긋나면
    /// 기하 계산 전체가 조용히 틀어진다.
    static func testWindowFrame() {
        let frame = WindowFrame(origin: CGPoint(x: 10, y: 20), size: CGSize(width: 30, height: 40))
        expect("rect composes origin and size", frame.rect, CGRect(x: 10, y: 20, width: 30, height: 40))
        expectName("equatable", "\(frame == WindowFrame(origin: frame.origin, size: frame.size))", "true")
    }

}
