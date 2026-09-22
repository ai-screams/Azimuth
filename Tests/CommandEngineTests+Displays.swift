// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 스냅·던지기·디스플레이 선택.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// 새 테스트 파일은 scripts/harness-sources.sh 의 HARNESS_TESTS 에 추가한다(한 곳).

import CoreGraphics
import Foundation

extension CommandEngineTests {

    static func testSnapHalves() {
        let base = CGRect(x: 300, y: 200, width: 700, height: 500)
        // snapThrow의 순수 폴백(스냅)은 그 방향 절반과 같다. 던지기 상태기계는 +Plan(CommandPlanPolicy)에서.
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

    static func testDisplayMove() {
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

    static func display(_ rect: CGRect, _ from: CGRect, _ to: CGRect) -> CGRect {
        FrameCalculator.displayMoveRect(rect, from: from, to: to)
    }

    // H-2: snapThrow의 "이미 스냅됨 → 던지기" 판정. 엄격 기하 OR Azimuth의 스냅 기록으로만 인정한다.
    static func testSnapDecision() {
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

    // DisplayGeometry 현재 화면 판정(순수 기하). Cocoa 좌표(원점 좌하단, Y 위로).
    /// 후보 목록과 창을 넣어 뽑힌 화면의 displayID 를 돌려준다(없으면 -1). 인덱스가 아니라 ID 로 단정하는
    /// 이유: fixture 의 ID 를 열거 순서와 반대로 두어 "ID 규칙"과 "순서 의존"을 구별하기 위해서다.
    static func bestMatchID(_ window: CGRect, _ candidates: [ScreenCandidate]) -> Int {
        guard let index = DisplayGeometry.bestMatchIndex(window: window, candidates: candidates) else { return -1 }
        return Int(candidates[index].displayID)
    }

    /// "창이 지금 어느 화면에 있나" — 모든 명령의 첫 판정. 면적 → 중심 포함 → 작은 displayID 순.
    /// 면적·동률 fixture 는 후보 순서를 뒤집어 한 번 더 돌린다: 규칙이 열거 순서에 기대면 여기서 갈린다.
    /// 뒤집지 않는 것은 nil 경계 셋과 원본 인덱스 행(뒤집으면 승자가 0번이 되어 검사의 의미가 사라진다)뿐이다.
    static func testBestMatch() {
        // A 는 왼쪽·ID 2, B 는 오른쪽·ID 1 — ID 를 순서와 반대로 둔다.
        let screenA = ScreenCandidate(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000), displayID: 2)
        let screenB = ScreenCandidate(frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000), displayID: 1)
        let ab = [screenA, screenB], ba = [screenB, screenA]

        // 1) 한 화면에만 겹침.
        let insideA = CGRect(x: 100, y: 100, width: 300, height: 300)
        expectName("only-A window picks A", "\(bestMatchID(insideA, ab))", "2")
        expectName("only-A window picks A (reversed)", "\(bestMatchID(insideA, ba))", "2")
        // 2) 면적이 다르면 큰 쪽(700:300 → A). 순서를 뒤집어도 같다.
        let mostlyA = CGRect(x: 300, y: 0, width: 1000, height: 1000)
        expectName("700:300 picks the larger overlap", "\(bestMatchID(mostlyA, ab))", "2")
        expectName("700:300 picks the larger overlap (reversed)", "\(bestMatchID(mostlyA, ba))", "2")
        // 3) 정확히 50:50 → 중심(x=1000)을 포함하는 화면. `contains`는 maxX 배타라 B 다.
        //    B 의 ID 가 더 작아 ID 규칙과 결과가 같으므로, ID 를 바꿔 한 번 더 — 그래도 B 여야 중심 규칙이다.
        let half = CGRect(x: 500, y: 0, width: 1000, height: 1000)
        expectName("50:50 picks the screen containing the center", "\(bestMatchID(half, ab))", "1")
        expectName("50:50 picks the screen containing the center (reversed)", "\(bestMatchID(half, ba))", "1")
        let screenA1 = ScreenCandidate(frame: screenA.frame, displayID: 1)
        let screenB2 = ScreenCandidate(frame: screenB.frame, displayID: 2)
        expectName("50:50 center rule beats smaller ID", "\(bestMatchID(half, [screenA1, screenB2]))", "2")
        // 4) 동률인데 중심이 어느 화면에도 없음(사이에 간격) → 작은 ID.
        let gapB = ScreenCandidate(frame: CGRect(x: 2000, y: 0, width: 1000, height: 1000), displayID: 1)
        let acrossGap = CGRect(x: 500, y: 0, width: 2000, height: 1000) // A 에 500, gapB 에 500, 중심 x=1500 은 간격
        expectName("tie with center in the gap picks the smaller ID", "\(bestMatchID(acrossGap, [screenA, gapB]))", "1")
        expectName("tie with center in the gap picks the smaller ID (reversed)",
                   "\(bestMatchID(acrossGap, [gapB, screenA]))", "1")
        // 5) 데드밴드: 면적 차 0.5 pt²(높이 1, 폭 100 과 99.5)는 동률 → 작은 ID(면적이 작은 쪽) 승.
        let wide = ScreenCandidate(frame: CGRect(x: 0, y: 0, width: 100, height: 1), displayID: 5)
        let nearlyAsWide = ScreenCandidate(frame: CGRect(x: 300, y: 0, width: 99.5, height: 1), displayID: 1)
        let spanBoth = CGRect(x: 0, y: 0, width: 399.5, height: 1) // 중심 x=199.75 는 간격
        expectName("0.5 pt² apart is a tie", "\(bestMatchID(spanBoth, [wide, nearlyAsWide]))", "1")
        expectName("0.5 pt² apart is a tie (reversed)", "\(bestMatchID(spanBoth, [nearlyAsWide, wide]))", "1")
        //    면적 차가 정확히 데드밴드(1 pt², 폭 100 과 99)여도 동률이다 — 비교가 `>=`여야 한다. `>`면 잡힌다.
        let exactlyOneLess = ScreenCandidate(frame: CGRect(x: 300, y: 0, width: 99, height: 1), displayID: 1)
        let spanExact = CGRect(x: 0, y: 0, width: 399, height: 1) // 중심 x=199.5 는 간격
        expectName("exactly 1 pt² apart is still a tie", "\(bestMatchID(spanExact, [wide, exactlyOneLess]))", "1")
        expectName("exactly 1 pt² apart is still a tie (reversed)",
                   "\(bestMatchID(spanExact, [exactlyOneLess, wide]))", "1")
        //    면적 차 2 pt²(폭 100 과 98)는 동률 아님 → ID 가 커도 면적 큰 쪽 승.
        let narrower = ScreenCandidate(frame: CGRect(x: 300, y: 0, width: 98, height: 1), displayID: 1)
        let spanBoth2 = CGRect(x: 0, y: 0, width: 398, height: 1)
        expectName("2 pt² apart is not a tie", "\(bestMatchID(spanBoth2, [wide, narrower]))", "5")
        expectName("2 pt² apart is not a tie (reversed)", "\(bestMatchID(spanBoth2, [narrower, wide]))", "5")
        // 6) 비추이 3화면: 면적 100/99.5/98.7, 중심 x=214.35 는 어느 화면에도 없음.
        //    최대(100)의 데드밴드 이내는 A·B 뿐 → 작은 ID 인 B. 순차 갱신이면 B 가 기준을 99.5 로 낮춰
        //    C(98.7) 가 동률로 끼어들고 ID 0 이 이겨 C 가 나온다.
        let triA = ScreenCandidate(frame: CGRect(x: 0, y: 0, width: 100, height: 1), displayID: 3)
        let triB = ScreenCandidate(frame: CGRect(x: 220, y: 0, width: 99.5, height: 1), displayID: 1)
        let triC = ScreenCandidate(frame: CGRect(x: 330, y: 0, width: 98.7, height: 1), displayID: 0)
        let spanThree = CGRect(x: 0, y: 0, width: 428.7, height: 1)
        expectName("non-transitive triple picks B, not C", "\(bestMatchID(spanThree, [triA, triB, triC]))", "1")
        expectName("non-transitive triple picks B, not C (reversed)",
                   "\(bestMatchID(spanThree, [triC, triB, triA]))", "1")
        // 7) 겹치지 않는 후보가 승자보다 앞 인덱스 — 거른 배열 안 오프셋을 돌려주면 ID 9 가 나온다.
        let farAway = ScreenCandidate(frame: CGRect(x: 5000, y: 0, width: 1000, height: 1000), displayID: 9)
        expectName("index is into candidates, not the filtered list", "\(bestMatchID(insideA, [farAway, screenA]))", "2")
        // 8) 겹치지 않음 → nil(wrapper 가 main → 첫 화면으로 폴백). edge 만 닿음(교집합 폭 0)도 겹침이 아니다.
        expectName("no overlap -> nil", "\(bestMatchID(CGRect(x: 3000, y: 0, width: 100, height: 100), ab))", "-1")
        expectName("edge-touch is not overlap", "\(bestMatchID(CGRect(x: 2000, y: 0, width: 100, height: 100), ab))", "-1")
        expectName("empty candidates -> nil", "\(bestMatchID(insideA, []))", "-1")
    }

    // DisplayGeometry 인접 화면 선택(순수 기하). Cocoa 좌표(원점 좌하단, Y 위로).
    static func testDisplayGeometry() {
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
}
