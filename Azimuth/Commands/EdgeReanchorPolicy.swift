//
//  EdgeReanchorPolicy.swift
//  Azimuth
//
//  "모든 크기 쓰기가 끝난 뒤, 작업영역 모서리에 닿아야 할 창을 실제 크기에 맞춰 그 모서리로 한 번 더
//  옮길 것인가"만 담당하는 순수 결정 계층(#100).
//
//  왜 따로 있나: 앱은 요청한 크기를 자르거나(최대 크기) 반올림한다. 스냅 목표의 origin은 요청 크기를
//  가정해 계산되므로, 앱이 목표보다 **작게** 잡히면 오른쪽·아래 모서리에 여백이 남는다(예: 최대 폭 700인
//  앱에 "Right 1/2" → 오른쪽에 260pt). 쓰기 단계(`WindowFrameWriter.writeFrame`)의 앵커 보정은 창이
//  목표보다 **클** 때만 걸렸고, 작을 때까지 거기서 보정하면 커지는 창의 "커지기 전" 크기로 위치를 잡는
//  문제가 있다. 그래서 마지막 크기 쓰기 **뒤에** 읽은 실제 frame으로만 판단한다.
//
//  순수 로직 파일 — AppKit/AX를 import하지 않는다(Commands/AGENTS.md). scripts/harness-sources.sh에 있다.
//

import CoreGraphics
import Foundation

/// 보정 판정에 필요한 값 전부.
nonisolated struct EdgeReanchorInput: Equatable {
    let anchor: FrameAnchor
    /// 명령이 요청한 frame.
    let target: CGRect
    /// 창이 있는 작업영역(AX 좌표). 모르면 nil — 닿은 모서리를 추론할 수 없어 보정하지 않는다.
    let workArea: CGRect?
    /// 모든 쓰기가 끝난 뒤 **다시 읽은** 실제 frame.
    let achieved: CGRect
    /// 크기가 목표와 "다르다"고 볼 최소 차이(`FrameApply.sizeTolerance`, 8pt). 터미널처럼 한 셀 미만으로
    /// 모자라는 앱은 옮기지 않는다.
    let sizeTolerance: CGFloat
    /// origin이 "다르다"고 볼 최소 차이(`FrameApply.originTolerance`, 2pt).
    let originTolerance: CGFloat
    /// **명령 시작부터** 이 판단 직전까지의 경과(초).
    let elapsed: TimeInterval
    /// 추가 AX 쓰기를 시작해도 되는 경과 상한(재시도와 같은 예산).
    let budget: TimeInterval
}

nonisolated enum EdgeReanchorPolicy {
    /// 옮길 origin, 옮길 필요가 없거나 판단할 수 없으면 nil.
    static func correctedOrigin(_ input: EdgeReanchorInput) -> CGPoint? {
        guard input.anchor == .workAreaEdges, let workArea = input.workArea,
              isValid(input.target), isValid(workArea), isValid(input.achieved),
              input.sizeTolerance.isFinite, input.sizeTolerance >= 0,
              input.originTolerance.isFinite, input.originTolerance >= 0,
              input.elapsed.isFinite, input.elapsed >= 0, input.budget.isFinite, input.budget > 0
        else { return nil }
        // 크기가 목표에 닿았으면(허용오차 안) 위치는 이미 목표대로다.
        let widthOff = abs(input.achieved.width - input.target.width) > input.sizeTolerance
        let heightOff = abs(input.achieved.height - input.target.height) > input.sizeTolerance
        guard widthOff || heightOff else { return nil }
        // 느린 앱에서 추가 쓰기로 프리즈를 늘리지 않는다(재시도와 같은 기준, 경계값도 초과로 본다).
        guard input.elapsed < input.budget else { return nil }
        let candidate = FrameCalculator.anchorOrigin(
            actualSize: input.achieved.size, requested: input.target, workArea: workArea
        )
        guard candidate.x.isFinite, candidate.y.isFinite else { return nil }
        // 두 모서리에 모두 닿는 목표(최대화)나 왼쪽·위 목표는 origin이 그대로라 여기서 걸러진다.
        let moved = abs(candidate.x - input.achieved.minX) > input.originTolerance
            || abs(candidate.y - input.achieved.minY) > input.originTolerance
        return moved ? candidate : nil
    }

    /// 좌표·크기가 유한하고 크기가 양수인가(NaN·무한·0이 모서리 계산으로 새지 않게).
    private static func isValid(_ rect: CGRect) -> Bool {
        FrameCalculator.isUsableFrame(rect)
    }
}
