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

    /// achieved가 pre에서 (허용오차 내) 실제로 달라졌는가 — Undo를 기록할지 판정한다.
    /// 무시된 쓰기(achieved≈pre)면 false라 직전 Undo를 무의미하게 덮지 않는다.
    static func changed(pre: CGRect, achieved: CGRect) -> Bool {
        changed(pre: pre, achieved: achieved, originTolerance: originTolerance, sizeTolerance: sizeTolerance)
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
