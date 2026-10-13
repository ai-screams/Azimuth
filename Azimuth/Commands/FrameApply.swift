//
//  FrameApply.swift
//  Azimuth
//
//  AX frame 쓰기의 순수(테스트 가능) 판정 로직. AXError·AXUIElement 등 AX 타입에 의존하지 않도록,
//  Writer가 실제 쓰기 결과·읽은 frame을 값으로 넘겨 이 함수들로 결과를 해석한다.
//
//  성공/실패(UI 피드백)와 "실제로 변했는가"(Undo)를 분리한다:
//   - 성공/실패는 AX 쓰기 결과로 판정한다(제약 앱이 목표 크기에 못 미쳐도 쓰기가 성공했으면 성공).
//   - Undo 기록은 achieved가 pre에서 실제로 달라졌는지로만 판정한다 — 무시된 쓰기(창이 그대로)나
//     부분 적용(한 축만 반영)을 올바르게 처리해, 직전 Undo를 무의미한 frame으로 덮거나 변경된 창의
//     복원 지점을 잃지 않는다.
//
//  ⚠️ 순수 로직 파일 — AppKit/AX를 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//  CoreGraphics만 사용.
//

import CoreGraphics

nonisolated enum FrameApply {
    /// origin 허용오차(pt). AX 왕복 반올림 흡수.
    static let originTolerance: CGFloat = 2
    /// size 허용오차(pt). 크기증분 앱(Terminal)이 한 셀(≈7pt) 모자라도 "도달"로 보게 넉넉히.
    static let sizeTolerance: CGFloat = 8
    /// 축이 "바뀌는가"(쓸지 말지) 판정용 소량 임계(pt). 명령은 축을 그대로 두거나 뚜렷이 바꾸므로
    /// 작게 둔다(반올림 노이즈만 흡수). "도달/변화"의 origin·sizeTolerance와는 목적이 다르다.
    static let changeEpsilon: CGFloat = 0.5

    /// target이 current의 origin을 (임계 초과로) 옮기는가 — 이동 쓰기·position 권한 요구 여부 판정.
    static func movesOrigin(from current: CGRect, to target: CGRect) -> Bool {
        abs(target.minX - current.minX) > changeEpsilon || abs(target.minY - current.minY) > changeEpsilon
    }

    /// target이 current의 size를 (임계 초과로) 바꾸는가 — 크기 쓰기·size 권한 요구 여부 판정.
    static func resizesSize(from current: CGRect, to target: CGRect) -> Bool {
        abs(target.width - current.width) > changeEpsilon || abs(target.height - current.height) > changeEpsilon
    }

    /// achieved가 pre에서 실제로 달라졌는가 — Undo를 기록할지 판정한다.
    /// 무시된 쓰기(achieved≈pre)면 false라 직전 Undo를 무의미하게 덮지 않는다.
    ///
    /// 임계는 **쓰기 여부를 정할 때와 같은 `changeEpsilon`** 이어야 한다: "쓸 만큼 달라졌으면 변한 것"이라는
    /// 불변식이 깨지면, 쓰기는 됐는데 변화로 안 쳐서 Undo를 잃는 구간이 생긴다(그러면 직전 명령의 Undo
    /// 항목이 살아남아, Undo 시 창이 한참 전 frame으로 튄다). `reached`의 관대한 허용오차는 "앱이 목표에
    /// 도달했나"라는 다른 질문용이므로 여기에 쓰면 안 된다.
    static func changed(pre: CGRect, achieved: CGRect) -> Bool {
        changed(pre: pre, achieved: achieved, originTolerance: changeEpsilon, sizeTolerance: changeEpsilon)
    }

    static func changed(pre: CGRect, achieved: CGRect, originTolerance: CGFloat, sizeTolerance: CGFloat) -> Bool {
        !approxEqual(achieved, pre, originTolerance: originTolerance, sizeTolerance: sizeTolerance)
    }

    /// achieved가 목표에 (허용오차 내) 도달했는가 — 재시도 판정·Undo 복원이 실제로 이뤄졌는지 확인에 쓴다.
    static func reached(target: CGRect, achieved: CGRect) -> Bool {
        reached(target: target, achieved: achieved, originTolerance: originTolerance, sizeTolerance: sizeTolerance)
    }

    static func reached(target: CGRect, achieved: CGRect, originTolerance: CGFloat, sizeTolerance: CGFloat) -> Bool {
        approxEqual(achieved, target, originTolerance: originTolerance, sizeTolerance: sizeTolerance)
    }

    private static func approxEqual(
        _ lhs: CGRect,
        _ rhs: CGRect,
        originTolerance: CGFloat,
        sizeTolerance: CGFloat
    ) -> Bool {
        abs(lhs.minX - rhs.minX) <= originTolerance
            && abs(lhs.minY - rhs.minY) <= originTolerance
            && abs(lhs.width - rhs.width) <= sizeTolerance
            && abs(lhs.height - rhs.height) <= sizeTolerance
    }
}

/// frame 적용 결과(writer → Executor). 순수 값이라 여기 둔다 — `CommandOutcome(pre:applied:snappedEdge:)`가
/// 이 값을 받아 하네스에서 배선까지 검증된다(#167).
///
/// 무엇을 담나: achieved(마지막으로 읽은 실제 frame)를 성공·실패 양쪽에서 실어, Executor가
/// "창이 실제로 변했는가"로 Undo를 판정하게 한다(부분 실패로 이동한 창의 복원 지점을 잃지 않고,
/// 무시된 쓰기로 직전 Undo를 덮지 않게). error가 nil이면 UI 성공, 있으면 실패/transient.
/// 읽기 자체가 실패하면 결과를 알 수 없으므로 achieved는 nil이다.
///
/// achieved가 nil일 때 상태 커밋의 유일한 근거가 `mayHaveMutated`다 — AX 쓰기가 하나라도 성공했다면
/// 창은 움직였을 수 있으므로 복원점을 남겨야 한다(감사 H-2). 판정 자체는 `CommandOutcomePolicy`가 한다.
nonisolated struct FrameApplyResult: Equatable {
    /// 실제로 노린 frame. 보통 요청의 target이고, 크기를 쓸 수 없는 창에 위치만 쓰기로 낮췄으면 그 frame이다
    /// (#167). Executor가 Undo·스냅 판정에 이 값을 써야 "이미 그 자리에 있던 창"을 무시된 쓰기로 오판하지 않는다.
    let target: CGRect
    let achieved: CGRect?
    let error: WindowCommandError?
    /// position/size 쓰기 중 하나라도 AX success를 반환했는가.
    let mayHaveMutated: Bool
}
