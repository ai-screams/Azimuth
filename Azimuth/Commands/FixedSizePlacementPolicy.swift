//
//  FixedSizePlacementPolicy.swift
//  Azimuth
//
//  크기를 바꿀 수 없는 창(`kAXSizeAttribute`가 settable이 아님)에 크기가 바뀌는 명령이 왔을 때, 실패하는
//  대신 **현재 크기 그대로** 어디에 둘지만 담당하는 순수 결정 계층(#167).
//
//  왜 `anchorOrigin`을 그대로 쓰지 않나: 그 함수는 앱이 목표 크기에 "가깝게" 잡힌 경우(#100)를 위한 것이라
//  닿은 모서리가 없는 축을 목표의 왼쪽·위에 둔다. 크기를 전혀 못 바꾸는 창에서는 그러면 Maximize가 화면
//  왼쪽 위 구석으로, Left 1/2가 화면 위쪽으로 붙는다. 여기서는 그런 축을 목표 영역의 가운데에 둔다.
//
//  순수 로직 파일 — AppKit/AX를 import하지 않는다(Commands/AGENTS.md). scripts/harness-sources.sh에 있다.
//

import CoreGraphics

/// AX에 "이 속성을 쓸 수 있나"를 물은 답. 조회 **실패**와 "쓸 수 없다"는 **답을** 구분한다 — 실패(타임아웃 등)를
/// 잠김으로 읽으면 크기 조절이 되는 창이 위치만 옮겨지고 조용히 성공한다.
nonisolated enum SettableAnswer: Equatable {
    case settable
    case notSettable
    /// 조회 자체가 실패했다(AXError ≠ success). 잠겼는지 알 수 없다.
    case unknown

    /// AX 조회 결과 → 답. writer가 `AXUIElementIsAttributeSettable`의 반환값을 `querySucceeded`로, 출력 플래그를
    /// `settable`로 넘긴다. 둘을 `&&`로 합쳐 Bool 하나로 만들면 실패가 "쓸 수 없다"가 된다 — 그 결함을 막는 자리다.
    /// AXError를 직접 받지 않는 이유: 이 계층은 AX를 import하지 않는다(Commands/AGENTS.md).
    init(querySucceeded: Bool, settable: Bool) {
        self = querySucceeded ? (settable ? .settable : .notSettable) : .unknown
    }
}

/// writer가 넘기는 AX 권한 조회 두 개. 호출 **여부와 순서를** 정책이 정하도록 값 대신 클로저로 받는다 —
/// 테스트가 호출을 기록해 "움직일 수 없는 창은 size를 묻지 않는다" 같은 순서 계약을 검증한다.
nonisolated struct SettableQueries {
    let positionSettable: () -> Bool
    let sizeSettable: () -> SettableAnswer
}

/// 크기를 바꾸려는 쓰기 요청을 어떻게 할지.
nonisolated enum FixedSizeWriteDecision: Equatable {
    /// 요청 그대로 쓴다(크기가 안 바뀌거나 크기를 쓸 수 있음).
    case proceed
    /// 이 frame(현재 크기 그대로)으로 위치만 쓴다.
    case retarget(CGRect)
    case fail(WindowCommandError)
}

nonisolated enum FixedSizePlacementPolicy {
    /// 쓰기 전 권한 확인 전체(#167). 순서가 계약이다:
    ///  1. 요청이 위치를 바꾸면 position을 **먼저** 묻는다. 움직일 수 없으면 size를 묻지 않고 `.notMovable` —
    ///     느린 앱에서 조회 하나가 해석 상한만큼 걸릴 수 있다.
    ///  2. 크기가 바뀔 때만 size를 묻고 `decide`에 넘긴다.
    ///  3. 위치만으로 낮춘 frame이 원래 요청과 달리 위치를 바꾸면(예: 이미 좌상단에 있던 창에 Maximize) 그때
    ///     처음 position을 묻는다. 원래 요청이 이미 위치를 바꿨다면 1에서 물었으므로 다시 묻지 않는다.
    static func resolve(
        anchor: FrameAnchor,
        current: CGRect,
        requested: CGRect,
        workArea: CGRect?,
        queries: SettableQueries
    ) -> FixedSizeWriteDecision {
        let movesRequested = FrameApply.movesOrigin(from: current, to: requested)
        if movesRequested, !queries.positionSettable() { return .fail(.notMovable) }
        let resizes = FrameApply.resizesSize(from: current, to: requested)
        let decision = decide(
            anchor: anchor, current: current, requested: requested, workArea: workArea,
            sizeSettable: resizes ? queries.sizeSettable() : .settable
        )
        guard case let .retarget(fixed) = decision else { return decision }
        let movesNow = FrameApply.movesOrigin(from: current, to: fixed)
        if movesNow, !movesRequested, !queries.positionSettable() { return .fail(.notMovable) }
        return decision
    }

    /// 쓰기 요청 → 그대로 / 위치만 / 실패. writer는 크기가 바뀌는 요청일 때만 size 권한을 물어 `sizeSettable`로
    /// 넘긴다(바뀌지 않으면 묻지 않고 `.settable`). 조회 실패(`.unknown`)는 예전처럼 `.notResizable`이다 —
    /// 잠겼다는 증거가 없으므로 위치만 옮기지 않는다.
    static func decide(
        anchor: FrameAnchor,
        current: CGRect,
        requested: CGRect,
        workArea: CGRect?,
        sizeSettable: SettableAnswer
    ) -> FixedSizeWriteDecision {
        guard FrameApply.resizesSize(from: current, to: requested) else { return .proceed }
        switch sizeSettable {
        case .settable:
            return .proceed
        case .unknown:
            return .fail(.notResizable)
        case .notSettable:
            guard let fixed = target(anchor: anchor, size: current.size, requested: requested, workArea: workArea)
            else { return .fail(.notResizable) }
            return .retarget(fixed)
        }
    }

    /// 위치만 쓸 frame(크기는 `size` 그대로). 대체를 허용하지 않는 명령이거나 판단할 수 없으면 nil —
    /// 호출자는 지금처럼 `.notResizable`로 실패한다.
    ///
    /// 허용 여부는 `anchor`로 정한다. `.workAreaEdges`(배치·Maximize·snapThrow·Move to Display·Move)만
    /// 허용하고, 상대 축소(명시적 모서리)와 Undo(`.topLeft`)는 막는다 — 상대 축소는 크기를 줄이는 것이
    /// 명령의 전부라 위치만 옮기면 다른 일을 하게 되고, Undo는 직전 실제 frame 복원이다.
    static func target(
        anchor: FrameAnchor,
        size: CGSize,
        requested: CGRect,
        workArea: CGRect?
    ) -> CGRect? {
        guard anchor == .workAreaEdges, let workArea,
              FrameCalculator.isUsableFrame(requested), FrameCalculator.isUsableFrame(workArea),
              FrameCalculator.isUsableFrame(CGRect(origin: .zero, size: size))
        else { return nil }
        let x = axisOrigin(
            length: size.width, target: requested.minX ... requested.maxX, area: workArea.minX ... workArea.maxX
        )
        let y = axisOrigin(
            length: size.height, target: requested.minY ... requested.maxY, area: workArea.minY ... workArea.maxY
        )
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// 목표가 작업영역 모서리에 닿은 것으로 볼 허용오차(`FrameCalculator.anchorOrigin`과 같은 2pt).
    private static let edgeEpsilon: CGFloat = 2

    /// 한 축의 origin. 목표가 앞쪽 모서리에만 닿으면 그 모서리, 뒤쪽에만 닿으면 그 모서리, 양쪽 다 닿거나
    /// 어느 쪽에도 닿지 않으면 목표 영역의 가운데. 마지막에 작업영역 안으로 클램프하고, 창이 작업영역보다
    /// 길면 앞쪽 모서리에 둔다(`Move`의 클램프 규칙과 같다).
    private static func axisOrigin(
        length: CGFloat,
        target: ClosedRange<CGFloat>,
        area: ClosedRange<CGFloat>
    ) -> CGFloat {
        let touchesStart = target.lowerBound <= area.lowerBound + edgeEpsilon
        let touchesEnd = target.upperBound >= area.upperBound - edgeEpsilon
        let raw: CGFloat = if touchesStart && !touchesEnd {
            target.lowerBound
        } else if touchesEnd && !touchesStart {
            target.upperBound - length
        } else {
            (target.lowerBound + target.upperBound - length) / 2
        }
        // 창이 작업영역보다 길면 upper < lowerBound라 바깥 max가 앞쪽 모서리를 고른다.
        return Swift.max(area.lowerBound, Swift.min(area.upperBound - length, raw))
    }
}
