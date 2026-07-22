// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 앵커·적용 판정·결과 커밋 정책.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// ⚠️ AppKit/AX 비의존. 새 테스트 파일은 scripts/test.sh·coverage.sh 양쪽에 추가해야 한다.

import CoreGraphics
import Foundation

extension CommandEngineTests {

    // 제약 앱이 목표 크기에 못 미칠 때 스냅 모서리를 유지하는 anchored origin.
    static func testAnchorOrigin() {
        let rightHalf = FrameCalculator.halfRect(.right, workArea: workArea)
        expectPoint("anchor right-half to actual width keeps right edge",
                    FrameCalculator.anchorOrigin(actualSize: CGSize(width: 1100, height: 1055),
                                                 requested: rightHalf, workArea: workArea),
                    CGPoint(x: 820, y: 25))
        let bottomHalf = FrameCalculator.halfRect(.bottom, workArea: workArea)
        expectPoint("anchor bottom-half to actual height keeps bottom edge",
                    FrameCalculator.anchorOrigin(actualSize: CGSize(width: 1920, height: 700),
                                                 requested: bottomHalf, workArea: workArea),
                    CGPoint(x: 0, y: 380))
        let leftHalf = FrameCalculator.halfRect(.left, workArea: workArea)
        expectPoint("anchor left-half keeps left edge (no shift)",
                    FrameCalculator.anchorOrigin(actualSize: CGSize(width: 1100, height: 1055),
                                                 requested: leftHalf, workArea: workArea),
                    CGPoint(x: 0, y: 25))
        // 앱 최소폭이 작업영역보다 큰 퇴화 케이스: 음수 origin이 아니라 좌상단으로 클램프.
        expectPoint("anchor clamps oversize min-width to on-screen origin",
                    FrameCalculator.anchorOrigin(actualSize: CGSize(width: 2000, height: 1055),
                                                 requested: rightHalf, workArea: workArea),
                    CGPoint(x: 0, y: 25))
    }

    // M-4: 명시적 anchor로 실제 크기에 맞춰 고정 모서리를 유지(앱 반올림에 의한 드리프트 방지).
    static func testAnchoredOrigin() {
        let target = CGRect(x: 400, y: 100, width: 400, height: 300) // maxX=800, maxY=400
        // 앱이 요청(400)보다 작게(396) 잡아도 오른쪽 모서리(800) 유지 → x=404. (기존 코드가 못 잡던 드리프트)
        expectPoint("right anchor keeps right edge when app rounds down",
                    FrameCalculator.anchoredOrigin(anchor: .right, actualSize: CGSize(width: 396, height: 300),
                                                   target: target, workArea: workArea),
                    CGPoint(x: 404, y: 100))
        // 앱이 요청보다 크게(420) 잡아도 오른쪽 모서리 유지 → x=380.
        expectPoint("right anchor keeps right edge when app overshoots",
                    FrameCalculator.anchoredOrigin(anchor: .right, actualSize: CGSize(width: 420, height: 300),
                                                   target: target, workArea: workArea),
                    CGPoint(x: 380, y: 100))
        // 하단 anchor: maxY(400) 고정, 실제 높이 290 → y=110.
        expectPoint("bottom anchor keeps bottom edge",
                    FrameCalculator.anchoredOrigin(anchor: .bottom, actualSize: CGSize(width: 400, height: 290),
                                                   target: target, workArea: workArea),
                    CGPoint(x: 400, y: 110))
        // topLeft: 크기가 달라도 origin 그대로.
        expectPoint("topLeft anchor keeps origin",
                    FrameCalculator.anchoredOrigin(anchor: .topLeft, actualSize: CGSize(width: 396, height: 290),
                                                   target: target, workArea: workArea),
                    CGPoint(x: 400, y: 100))
        // 최소폭이 큰 제약 앱을 화면 왼쪽 근처에서 우측 앵커로 축소해도 작업영역 밖으로 밀리지 않는다.
        // (회귀 방지: 클램프가 없으면 maxX=350·실제폭 800에서 x=-450으로 화면 밖에 놓였다.)
        expectPoint("right anchor clamps into the work area (constrained app near left edge)",
                    FrameCalculator.anchoredOrigin(anchor: .right, actualSize: CGSize(width: 800, height: 600),
                                                   target: CGRect(x: 200, y: 200, width: 150, height: 600),
                                                   workArea: workArea),
                    CGPoint(x: 0, y: 200))
        expectPoint("bottom anchor clamps into the work area",
                    FrameCalculator.anchoredOrigin(anchor: .bottom, actualSize: CGSize(width: 400, height: 2000),
                                                   target: CGRect(x: 100, y: 200, width: 400, height: 300),
                                                   workArea: workArea),
                    CGPoint(x: 100, y: 25))
        // 앱이 비정상 크기(NaN)를 보고하면 앵커 보정을 포기하고 목표 origin — NaN이 AX 쓰기로 새지 않게.
        expectPoint("non-finite actual size falls back to target origin",
                    FrameCalculator.anchoredOrigin(anchor: .right,
                                                   actualSize: CGSize(width: CGFloat.nan, height: 600),
                                                   target: CGRect(x: 400, y: 100, width: 400, height: 300),
                                                   workArea: workArea),
                    CGPoint(x: 400, y: 100))
        // workAreaEdges: 기존 작업영역 모서리 추론 경로로 위임.
        let rightHalf = FrameCalculator.halfRect(.right, workArea: workArea)
        expectPoint("workAreaEdges delegates to edge inference",
                    FrameCalculator.anchoredOrigin(anchor: .workAreaEdges,
                                                   actualSize: CGSize(width: 1100, height: 1055),
                                                   target: rightHalf, workArea: workArea),
                    CGPoint(x: 820, y: 25))
        // 명령 → anchor 의도 매핑.
        expectName("relative right maps to right anchor",
                   "\(WindowCommand.relativeHalf(.right).frameAnchor == FrameAnchor.right)", "true")
        expectName("relative bottom maps to bottom anchor",
                   "\(WindowCommand.relativeTwoThird(.bottom).frameAnchor == FrameAnchor.bottom)", "true")
        expectName("relative left maps to topLeft anchor",
                   "\(WindowCommand.relativeHalf(.left).frameAnchor == FrameAnchor.topLeft)", "true")
        expectName("relative top maps to topLeft anchor",
                   "\(WindowCommand.relativeTwoThird(.top).frameAnchor == FrameAnchor.topLeft)", "true")
        expectName("undo maps to topLeft anchor",
                   "\(WindowCommand.undo.frameAnchor == FrameAnchor.topLeft)", "true")
        expectName("maximize maps to workAreaEdges anchor",
                   "\(WindowCommand.maximize.frameAnchor == FrameAnchor.workAreaEdges)", "true")
        expectName("snapThrow maps to workAreaEdges anchor",
                   "\(WindowCommand.snapThrow(.left).frameAnchor == FrameAnchor.workAreaEdges)", "true")
    }

    // WindowFrameWriter가 anchored 보정을 걸지 판정하는 순수 임계 함수(경계값).
    static func testIsConstrained() {
        let target = CGSize(width: 1000, height: 800)
        // 목표와 같음 → 제약 아님.
        expectName("equal size not constrained",
                   "\(FrameCalculator.isConstrained(actualSize: target, target: target, tolerance: 8))", "false")
        // tolerance 정확히 = 경계(초과 아님) → 제약 아님(> 비교).
        expectName("exactly at tolerance not constrained",
                   "\(FrameCalculator.isConstrained(actualSize: CGSize(width: 1008, height: 800), target: target, tolerance: 8))", "false")
        // tolerance 직후(1008.1) → 제약.
        expectName("just over tolerance is constrained (width)",
                   "\(FrameCalculator.isConstrained(actualSize: CGSize(width: 1008.1, height: 800), target: target, tolerance: 8))", "true")
        // 높이 축 단독 초과 → 제약.
        expectName("height-only over tolerance is constrained",
                   "\(FrameCalculator.isConstrained(actualSize: CGSize(width: 1000, height: 809), target: target, tolerance: 8))", "true")
        // 목표보다 작음 → 제약 아님(축소는 anchored 보정 대상 아님).
        expectName("smaller than target not constrained",
                   "\(FrameCalculator.isConstrained(actualSize: CGSize(width: 500, height: 400), target: target, tolerance: 8))", "false")
    }

    // L-3: AX에서 읽은 frame의 유효성(유한·양수 크기) 방어 술어.
    static func testUsableFrame() {
        expectName("normal frame is usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: 0, y: 25, width: 800, height: 600)))", "true")
        expectName("zero width not usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: 0, y: 0, width: 0, height: 600)))", "false")
        expectName("negative width not usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: 0, y: 0, width: -10, height: 600)))", "false")
        expectName("NaN origin not usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: CGFloat.nan, y: 0, width: 800, height: 600)))", "false")
        expectName("infinite size not usable",
                   "\(FrameCalculator.isUsableFrame(CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 600)))", "false")
    }

    // H-1: 적용 결과 판정 순수 함수 — Undo는 achieved가 pre에서 변했는지, 도달은 target 기준.
    static func testFrameApply() {
        let pre = CGRect(x: 0, y: 25, width: 800, height: 600)
        // 변화 없음(무시된 쓰기) → Undo 미기록.
        expectName("unchanged frame is not undo-worthy",
                   "\(FrameApply.changed(pre: pre, achieved: pre))", "false")
        // 쓰기 임계(changeEpsilon 0.5pt) 이하의 미세 차이만 "변화 없음" — AX 왕복 반올림 잡음 흡수.
        expectName("sub-epsilon jitter is not changed",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 0.3, y: 25.2, width: 800.4, height: 600)))",
                   "false")
        // 회귀 방지: 쓰기가 일어날 만큼(>0.5pt) 달라졌으면 반드시 "변함"이어야 한다. 과거엔 size 8pt
        // 허용오차를 써서 5pt 축소가 "변화 없음"이 되어 undo가 기록되지 않았고, 그 결과 직전 명령의
        // undo 항목이 남아 Undo 시 창이 한참 전 frame으로 튀었다.
        expectName("5pt resize is changed (undo must be recorded)",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 0, y: 25, width: 795, height: 600)))", "true")
        expectName("1pt move is changed (undo must be recorded)",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 1, y: 25, width: 800, height: 600)))", "true")
        // 불변식: "쓴다"(movesOrigin/resizesSize)와 "변했다"(changed)는 같은 임계를 써야 한다.
        // 상대 축소 100pt 하한에 걸리는 실제 케이스로 고정한다(105 → 100).
        let beforeFloor = CGRect(x: 300, y: 200, width: 105, height: 600)
        let floored = CGRect(x: 300, y: 200, width: 100, height: 600)
        expectName("write-decision and changed agree at the 100pt floor",
                   "\(FrameApply.resizesSize(from: beforeFloor, to: floored) == FrameApply.changed(pre: beforeFloor, achieved: floored))",
                   "true")
        // 위치만 바뀜(부분 적용) → 변화로 인정 → Undo 기록.
        expectName("position-only move is changed",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 400, y: 25, width: 800, height: 600)))", "true")
        // 크기만 바뀜(size 축 8pt 초과) → 변화.
        expectName("size-only change beyond tolerance is changed",
                   "\(FrameApply.changed(pre: pre, achieved: CGRect(x: 0, y: 25, width: 900, height: 600)))", "true")
        // 목표 도달: target과 achieved가 허용오차 내(제약 앱 셀 오차 포함).
        let target = CGRect(x: 960, y: 25, width: 960, height: 1055)
        expectName("reached target within tolerance",
                   "\(FrameApply.reached(target: target, achieved: CGRect(x: 961, y: 26, width: 955, height: 1055)))", "true")
        // 제약 앱: 크기가 목표보다 8pt 넘게 크면 미도달.
        expectName("constrained size beyond tolerance not reached",
                   "\(FrameApply.reached(target: target, achieved: CGRect(x: 960, y: 25, width: 1100, height: 1055)))", "false")
        // M-3: 축별 변경 판정(해당 축만 쓰고 권한을 요구하도록).
        let base = CGRect(x: 100, y: 100, width: 400, height: 300)
        let moved = CGRect(x: 200, y: 100, width: 400, height: 300)
        let resized = CGRect(x: 100, y: 100, width: 600, height: 300)
        expectName("move-only changes origin", "\(FrameApply.movesOrigin(from: base, to: moved))", "true")
        expectName("move-only does not resize", "\(FrameApply.resizesSize(from: base, to: moved))", "false")
        expectName("resize-only changes size", "\(FrameApply.resizesSize(from: base, to: resized))", "true")
        expectName("resize-only does not move", "\(FrameApply.movesOrigin(from: base, to: resized))", "false")
        expectName("identical frame neither moves nor resizes",
                   "\(FrameApply.movesOrigin(from: base, to: base) || FrameApply.resizesSize(from: base, to: base))", "false")
    }

    // 결과 커밋 정책 — AX 없이 부분 실패/읽기 실패 조합에서 Undo·Snap 상태를 어떻게 커밋하는지.
    // 이 조합들이 자동 검증 밖에 있었다(감사 H-2/H-3).
    static func testOutcomePolicy() {
        let pre = CGRect(x: 0, y: 25, width: 960, height: 1055)
        let moved = CGRect(x: 960, y: 25, width: 960, height: 1055)
        // 부분 적용: position은 반영되고 size 쓰기는 실패해 목표 절반에 못 미친 frame.
        let partial = CGRect(x: 960, y: 25, width: 700, height: 1055)

        struct Outcome {
            var target: CGRect
            var achieved: CGRect?
            var failed = false
            var mutated = false
            var edge: SnapEdge?
        }
        func decide(_ outcome: Outcome) -> OutcomeDecision {
            CommandOutcomePolicy.decide(CommandOutcome(
                pre: pre, target: outcome.target, achieved: outcome.achieved,
                failed: outcome.failed, mayHaveMutated: outcome.mutated, snappedEdge: outcome.edge
            ))
        }

        // 성공 스냅: 복원점과 스냅 상태를 함께 커밋한다(기존 동작 유지).
        expectDecision("successful snap records undo and snap state",
                       decide(Outcome(target: moved, achieved: moved, mutated: true, edge: .right)),
                       OutcomeDecision(recordUndo: true, snap: .record(.right, frame: moved)))
        // ① 의도된 no-op — 인접 디스플레이 없는 snapThrow는 target이 곧 현재 frame이다. 창은
        // 그대로지만 여전히 그 edge에 스냅돼 있으므로, undo는 덮지 않고 스냅 상태만 갱신한다.
        expectDecision("intended no-op (target == pre) refreshes snap state",
                       decide(Outcome(target: pre, achieved: pre, edge: .left)),
                       OutcomeDecision(recordUndo: false, snap: .record(.left, frame: pre)))
        // ② 무시된 쓰기 — target이 달랐는데 AX가 .success를 돌려주고도 창이 안 움직였다.
        // ①과 결과(achieved == pre)는 같지만 이 창은 스냅된 적이 없다. 여기서 기록하면 다음
        // 같은 방향 입력이 "이미 스냅됨"으로 오판해 창을 인접 디스플레이로 던진다.
        expectDecision("successful-but-ignored write must not commit snap state",
                       decide(Outcome(target: moved, achieved: pre, mutated: true, edge: .right)),
                       OutcomeDecision(recordUndo: false, snap: .keep))
        // 핵심(H-2): position만 적용되고 size가 실패한 부분 frame을 "스냅 완료"로 커밋하면,
        // 다음 같은 방향 입력이 창을 스냅된 것으로 오판해 다른 디스플레이로 던진다.
        expectDecision("partially applied snap must not commit snap state",
                       decide(Outcome(target: moved, achieved: partial, failed: true, mutated: true, edge: .right)),
                       OutcomeDecision(recordUndo: true, snap: .clear))
        // transient 실패(Space 전환 등)로 창이 전혀 안 움직였으면 기존 스냅 상태는 아직 유효하다.
        expectDecision("failed no-op keeps existing snap state",
                       decide(Outcome(target: moved, achieved: pre, failed: true, edge: .right)),
                       OutcomeDecision(recordUndo: false, snap: .keep))
        // 핵심(H-2): 쓰기는 반영됐는데 최종 read가 실패하면 결과를 모른다. 복원점을 남기지 않으면
        // 직전 명령의 undo 항목이 살아남아 Undo 시 창이 한참 전 frame으로 튄다 → 보수적으로 기록.
        expectDecision("write succeeded but final read failed still leaves a restore point",
                       decide(Outcome(target: moved, achieved: nil, failed: true, mutated: true, edge: .right)),
                       OutcomeDecision(recordUndo: true, snap: .clear))
        // 쓰기 자체가 안 먹었고 read도 실패 → 창이 변했다고 볼 근거가 없다. 아무것도 건드리지 않는다.
        expectDecision("no write and no read leaves both stores untouched",
                       decide(Outcome(target: moved, achieved: nil, failed: true, edge: .right)),
                       OutcomeDecision(recordUndo: false, snap: .keep))
        // 스냅이 아닌 일반 명령(maximize 등)은 스냅 상태를 건드리지 않는다.
        expectDecision("non-snap command does not touch snap state",
                       decide(Outcome(target: moved, achieved: moved, mutated: true)),
                       OutcomeDecision(recordUndo: true, snap: .keep))
        // 일반 명령이 부분 적용되면 창은 더 이상 기록된 스냅 frame이 아니다 → 상태를 버린다.
        expectDecision("partially applied non-snap command clears stale snap state",
                       decide(Outcome(target: moved, achieved: partial, failed: true, mutated: true)),
                       OutcomeDecision(recordUndo: true, snap: .clear))
    }
}
