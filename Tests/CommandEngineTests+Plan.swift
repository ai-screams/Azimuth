// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 목표 frame 계획(CommandPlanPolicy).
//
// snapThrow의 상태기계(안 스냅 → 스냅, 이미 스냅 → 인접 디스플레이의 반대쪽 절반으로 던지기, 인접 없음 →
// 제자리)와 moveToDisplay의 목적지 선택. 창을 옆 모니터로 던지는 것은 이 앱의 간판 기능인데 Executor 안에
// 있어 오랫동안 회귀 그물이 없었다 — 인접 작업영역과 스냅 기록을 값으로 넣으므로 AX 없이 전수 검증한다.
//
// 모든 단정은 expectPlan(통째 동등성)으로 한다. target과 snappedEdge를 따로 검사하면 한쪽을 빼먹어도
// 통과한다(예: 인접 없음 분기가 frame은 맞는데 edge를 반대로 돌려주는 변이).
// 네 방향을 전부 돈다 — 한 방향만 보면 `opposite` 표가 뒤바뀌어도 통과한다.

import CoreGraphics
import Foundation

extension CommandEngineTests {

    static func plan(
        _ command: WindowCommand, current: CGRect, recorded: SnapRecord? = nil, adjacent: CGRect? = nil
    ) -> CommandPlan {
        CommandPlanPolicy.decide(CommandPlanInput(
            command: command, current: current, workArea: workArea, recorded: recorded, adjacentWorkArea: adjacent
        ))
    }

    /// 그 방향의 인접 디스플레이 작업영역. 현재 작업영역(1920×1055)과 크기를 다르게 둔다 — displayMoveRect의
    /// from/to가 뒤바뀐 배선은 두 사각형이 같으면 잡히지 않는다.
    static func adjacentArea(_ edge: SnapEdge) -> CGRect {
        switch edge {
        case .left: CGRect(x: -1440, y: 0, width: 1440, height: 900)
        case .right: CGRect(x: 1920, y: 0, width: 1440, height: 900)
        case .top: CGRect(x: 0, y: -900, width: 1440, height: 900)
        case .bottom: CGRect(x: 0, y: 1080, width: 1440, height: 900)
        }
    }

    /// 제약 앱이 그 방향으로 스냅된 모습 — 가장자리에 붙었지만 정확한 반쪽에는 못 미친다.
    /// 기하로는 스냅으로 안 보이고 기록으로만 인정된다. `halfRect`와 다른 값이어야 "제자리 유지"와
    /// "재스냅"이 구별된다.
    static func constrainedSnap(_ edge: SnapEdge) -> CGRect {
        switch edge {
        case .left: CGRect(x: 0, y: 25, width: 700, height: 1055)
        case .right: CGRect(x: 1220, y: 25, width: 700, height: 1055)
        case .top: CGRect(x: 0, y: 25, width: 1920, height: 400)
        case .bottom: CGRect(x: 0, y: 680, width: 1920, height: 400)
        }
    }

    static func testSnapThrowPlan() {
        let floating = CGRect(x: 300, y: 200, width: 700, height: 500)
        for edge in [SnapEdge.left, .right, .top, .bottom] {
            let name = edge.token
            let half = FrameCalculator.halfRect(edge, workArea: workArea)
            let adjacent = adjacentArea(edge)
            // 1) 안 스냅됨 → 그 방향 절반으로 스냅. 인접이 있어도 던지지 않는다.
            expectPlan("\(name): unsnapped window snaps to its half",
                       plan(.snapThrow(edge), current: floating, adjacent: adjacent),
                       CommandPlan(target: half, snappedEdge: edge))
            // 2) 이미 스냅됨(엄격 기하) → 인접 디스플레이의 반대쪽 절반으로 던진다. edge도 반대쪽.
            expectPlan("\(name): geometrically snapped window throws to the adjacent display",
                       plan(.snapThrow(edge), current: half, adjacent: adjacent),
                       CommandPlan(target: FrameCalculator.halfRect(edge.opposite, workArea: adjacent),
                                   snappedEdge: edge.opposite))
            // 2') 이미 스냅됨(기록만 — 제약 앱) → 역시 던진다. 기록이 정책까지 배선돼야 통과한다.
            let constrained = constrainedSnap(edge)
            let record = SnapRecord(edge: edge, frame: constrained)
            expectPlan("\(name): recorded constrained snap throws to the adjacent display",
                       plan(.snapThrow(edge), current: constrained, recorded: record, adjacent: adjacent),
                       CommandPlan(target: FrameCalculator.halfRect(edge.opposite, workArea: adjacent),
                                   snappedEdge: edge.opposite))
            // 3) 이미 스냅됐는데 인접 없음 → 현재 frame 그대로(재스냅으로 밀지 않는다). edge는 진입 edge.
            //    fixture가 제약 앱 flavor인 이유: current == halfRect면 "그대로"와 "재스냅"이 같은 값이다.
            expectPlan("\(name): snapped window with no adjacent display stays put",
                       plan(.snapThrow(edge), current: constrained, recorded: record, adjacent: nil),
                       CommandPlan(target: constrained, snappedEdge: edge))
            // 기록이 다른 방향이면 그 방향엔 스냅 아님 → 던지지 않고 스냅. 기록만 있다고 던지면 잡힌다.
            let otherRecord = SnapRecord(edge: edge.opposite, frame: constrainedSnap(edge.opposite))
            expectPlan("\(name): a snap recorded for the opposite edge does not count",
                       plan(.snapThrow(edge), current: constrainedSnap(edge.opposite), recorded: otherRecord,
                            adjacent: adjacent),
                       CommandPlan(target: half, snappedEdge: edge))
        }
    }

    static func testMoveToDisplayPlan() {
        let floating = CGRect(x: 300, y: 200, width: 700, height: 500)
        for edge in [SnapEdge.left, .right, .top, .bottom] {
            let name = edge.token
            let adjacent = adjacentArea(edge)
            // 인접 있음 → 상대 위치·크기를 유지해 이동. 스냅 계열이 아니므로 edge는 nil.
            expectPlan("\(name): move to display keeps relative placement",
                       plan(.moveToDisplay(edge), current: floating, adjacent: adjacent),
                       CommandPlan(target: FrameCalculator.displayMoveRect(floating, from: workArea, to: adjacent),
                                   snappedEdge: nil))
            // 인접 없음 → 제자리.
            expectPlan("\(name): move to display with no adjacent display stays put",
                       plan(.moveToDisplay(edge), current: floating, adjacent: nil),
                       CommandPlan(target: floating, snappedEdge: nil))
        }
    }

    static func testPlanDelegation() {
        // 인접·스냅 정보를 쓰지 않는 명령은 FrameCalculator에 그대로 위임하고 edge는 nil.
        // 인접과 기록을 넣어 둔 채로 검사한다 — 있어도 무시돼야 한다.
        let current = CGRect(x: 300, y: 200, width: 700, height: 500)
        let record = SnapRecord(edge: .left, frame: current)
        let adjacent = adjacentArea(.right)
        let delegated: [WindowCommand] = [
            .maximize, .maximizeGaps, absolute(.horizontal, .half, .first), .move(.center),
            .relativeHalf(.left), .relativeTwoThird(.top), .undo,
        ]
        for command in delegated {
            expectPlan("\(command.identifier) delegates to FrameCalculator",
                       plan(command, current: current, recorded: record, adjacent: adjacent),
                       CommandPlan(target: target(command, current), snappedEdge: nil))
        }
    }

    static func testAdjacentEdge() {
        // Executor는 이 값으로만 인접 작업영역을 조회한다. 정책 테스트는 인접을 값으로 넣으므로 이 배선의
        // 유일한 분기점은 여기서 따로 고정해야 한다.
        for edge in [SnapEdge.left, .right, .top, .bottom] {
            expectName("snapThrow(\(edge.token)) looks \(edge.token)",
                       WindowCommand.snapThrow(edge).adjacentEdge?.token ?? "nil", edge.token)
            expectName("moveToDisplay(\(edge.token)) looks \(edge.token)",
                       WindowCommand.moveToDisplay(edge).adjacentEdge?.token ?? "nil", edge.token)
        }
        let edgeless: [WindowCommand] = [
            .maximize, .maximizeGaps, absolute(.horizontal, .half, .first), .move(.center),
            .relativeHalf(.left), .relativeTwoThird(.top), .undo,
        ]
        for command in edgeless {
            expectName("\(command.identifier) has no adjacent edge", command.adjacentEdge?.token ?? "nil", "nil")
        }
    }
}
