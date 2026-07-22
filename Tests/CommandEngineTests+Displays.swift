// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 스냅·던지기·디스플레이 선택.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// ⚠️ AppKit/AX 비의존. 새 테스트 파일은 scripts/test.sh·coverage.sh 양쪽에 추가해야 한다.

import CoreGraphics
import Foundation

extension CommandEngineTests {

    static func testSnapHalves() {
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
