//
//  CommandOutcomePolicy.swift
//  Azimuth
//
//  "AX 쓰기가 이렇게 끝났을 때 Undo/Snap 상태를 어떻게 커밋할 것인가"만 담당하는 순수 결정 계층.
//  Executor에서 이 판단을 분리한 이유는 테스트다 — 부분 적용·최종 read 실패 같은 위험한 조합은
//  AX 없이는 재현할 수 없었는데(감사 H-2/H-3), 값만 받는 함수로 내리면 기존 swiftc 하네스에서
//  전수 검증할 수 있다.
//
//  ⚠️ 순수 로직 파일 — AppKit/AX를 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//  CoreGraphics만 사용. 새 순수 파일은 test.sh·coverage.sh 소스 목록에 직접 추가해야 한다.
//

import CoreGraphics

/// 한 명령의 AX 적용 결과를 상태 커밋 판단에 필요한 값만으로 요약한 것.
nonisolated struct CommandOutcome: Equatable {
    /// 명령 실행 직전에 읽은 창 frame(복원점 후보).
    let pre: CGRect
    /// 적용 후 마지막으로 읽은 실제 frame. 읽기 자체가 실패하면 nil(결과를 알 수 없음).
    let achieved: CGRect?
    /// 사용자에게 실패로 보고되는가(AX 쓰기 오류 또는 최종 read 실패).
    let failed: Bool
    /// position/size 쓰기 중 하나라도 AX success였는가 — achieved가 nil일 때 "창이 움직였을 수도
    /// 있다"를 판단하는 유일한 근거다.
    let mayHaveMutated: Bool
    /// 이 명령이 성공했다면 창이 스냅되는 edge. 스냅 계열이 아니면 nil.
    let snappedEdge: SnapEdge?
}

/// 스냅 상태 저장소에 무엇을 할지.
nonisolated enum SnapCommit: Equatable {
    /// 그대로 둔다(이 명령이 스냅 상태에 대해 아무 정보도 주지 않음).
    case keep
    /// 이 edge로 스냅됐다고 기록한다. frame은 목표가 아니라 **실제로 읽은** frame이어야 한다 —
    /// 제약 앱이 정확한 반쪽에 못 미쳐도 다음 입력이 "이미 스냅됨"을 알아보게 하는 근거이기 때문이다.
    case record(SnapEdge, frame: CGRect)
    /// 기록을 버린다(창이 알 수 없는 중간 상태 — 남겨두면 다음 입력을 오판시킨다).
    case clear
}

nonisolated struct OutcomeDecision: Equatable {
    let recordUndo: Bool
    let snap: SnapCommit
}

nonisolated enum CommandOutcomePolicy {
    static func decide(_ outcome: CommandOutcome) -> OutcomeDecision {
        guard let achieved = outcome.achieved else {
            // 결과를 읽지 못했다. 쓰기가 하나라도 성공했다면 창이 움직였을 수 있으므로 보수적으로
            // 복원점을 남기고(안 남기면 직전 명령의 undo 항목이 살아남아 Undo가 한참 전으로 튄다)
            // 스냅 상태는 버린다(어디에 있는지 모르는 창을 "스냅됨"으로 둘 수 없다).
            return OutcomeDecision(recordUndo: outcome.mayHaveMutated, snap: outcome.mayHaveMutated ? .clear : .keep)
        }
        // 복원점은 창이 "실제로" 변했을 때만 — 무시된 쓰기·no-op이 직전 undo를 덮지 않게 한다.
        let changed = FrameApply.changed(pre: outcome.pre, achieved: achieved)
        guard !outcome.failed else {
            // 실패했는데 창이 변했다 = 부분 적용. 이 중간 frame을 "스냅 완료"로 커밋하면 다음 같은
            // 방향 입력이 창을 스냅된 것으로 오판해 다른 디스플레이로 던진다(감사 H-2).
            // 반대로 전혀 안 움직인 실패(Space 전환 등 transient)면 기존 스냅 상태는 아직 유효하다.
            return OutcomeDecision(recordUndo: changed, snap: changed ? .clear : .keep)
        }
        guard let edge = outcome.snappedEdge else {
            return OutcomeDecision(recordUndo: changed, snap: .keep)
        }
        return OutcomeDecision(recordUndo: changed, snap: .record(edge, frame: achieved))
    }
}
