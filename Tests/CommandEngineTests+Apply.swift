// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 앵커·적용 판정·결과 커밋 정책.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).
// 새 테스트 파일은 scripts/harness-sources.sh 의 HARNESS_TESTS 에 추가한다(한 곳).

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

    // #167: 크기를 쓸 수 없는 창은 현재 크기 그대로, 목표가 닿은 모서리에 붙이고 아니면 목표 영역 가운데에 둔다.
    // workArea = (0, 25, 1920×1055) → 세로 가운데는 (25 + 1080 − h) / 2.
    static func testFixedSizePlacement() {
        let size = CGSize(width: 800, height: 600)
        func place(
            _ requested: CGRect, size: CGSize = size, anchor: FrameAnchor = .workAreaEdges, area: CGRect? = workArea
        ) -> CGRect? {
            FixedSizePlacementPolicy.target(anchor: anchor, size: size, requested: requested, workArea: area)
        }
        func expectFrame(_ label: String, _ got: CGRect?, _ want: CGRect?) {
            switch (got, want) {
            case (nil, nil):
                checks += 1
            case let (got?, want?):
                expect(label, got, want)
            default:
                checks += 1
                failures += 1
                print("FAIL \(label): got \(String(describing: got)) want \(String(describing: want))")
            }
        }
        let leftHalf = FrameCalculator.halfRect(.left, workArea: workArea)
        let rightHalf = FrameCalculator.halfRect(.right, workArea: workArea)
        let bottomRight = CGRect(x: 960, y: 552.5, width: 960, height: 527.5)
        let centerThird = CGRect(x: 640, y: 25, width: 640, height: 1055)
        // 이것을 실패시키는 것: 앞쪽 모서리 분기를 지우면(가운데로 떨어짐) x=80이 된다.
        expectFrame("left half: left edge, vertically centered",
                    place(leftHalf), CGRect(x: 0, y: 252.5, width: 800, height: 600))
        // 이것을 실패시키는 것: 뒤쪽 모서리 분기를 지우면 x=1040(목표 영역 가운데)이 된다.
        expectFrame("right half: right edge, vertically centered",
                    place(rightHalf), CGRect(x: 1120, y: 252.5, width: 800, height: 600))
        expectFrame("bottom-right quarter: bottom-right corner",
                    place(bottomRight), CGRect(x: 1120, y: 480, width: 800, height: 600))
        // 양쪽 모서리에 닿는 목표(최대화)는 가운데 — 기존 anchorOrigin이면 좌상단 (0, 25)이었다.
        expectFrame("maximize: centered on the screen",
                    place(workArea), CGRect(x: 560, y: 252.5, width: 800, height: 600))
        let gapped = FrameCalculator.targetFrame(for: .maximizeGaps, current: workArea, workArea: workArea)
        expectFrame("gapped maximize: centered",
                    place(gapped), CGRect(x: 560, y: 252.5, width: 800, height: 600))
        expectFrame("center third: centered in the column",
                    place(centerThird), CGRect(x: 560, y: 252.5, width: 800, height: 600))
        // 목표보다 큰 창도 같은 규칙: 닿은 모서리를 지키고, 가운데 칸이면 칸의 가운데에 맞춘다.
        let wide = CGSize(width: 1200, height: 600)
        expectFrame("wider than the half keeps the right edge",
                    place(rightHalf, size: wide), CGRect(x: 720, y: 252.5, width: 1200, height: 600))
        expectFrame("wider than the column centers on it",
                    place(centerThird, size: wide), CGRect(x: 360, y: 252.5, width: 1200, height: 600))
        // 클램프: 가운데에 맞춘 위치가 작업영역 밖이면 안으로, 작업영역보다 크면 앞쪽 모서리로.
        // 이것을 실패시키는 것: 클램프를 지우면 모서리에 닿지 않는 목표(1100–1800)의 가운데 x=500에 놓여 화면 밖으로 나간다.
        expectFrame("clamped inside the work area",
                    place(CGRect(x: 1100, y: 25, width: 700, height: 1055), size: CGSize(width: 1900, height: 600)),
                    CGRect(x: 20, y: 252.5, width: 1900, height: 600))
        expectFrame("larger than the work area pins to the leading edge",
                    place(workArea, size: CGSize(width: 2000, height: 1200)),
                    CGRect(x: 0, y: 25, width: 2000, height: 1200))
        // 모서리 판정 허용오차 2pt(이하는 닿음, 넘으면 안 닿음).
        // 이것을 실패시키는 것: 비교를 < 로 바꾸면 2pt에서 갈라진다.
        expectFrame("2pt off the edge still counts as touching",
                    place(CGRect(x: 2, y: 25, width: 958, height: 1055)),
                    CGRect(x: 2, y: 252.5, width: 800, height: 600))
        expectFrame("3pt off the edge centers in the target",
                    place(CGRect(x: 3, y: 25, width: 957, height: 1055)),
                    CGRect(x: 81.5, y: 252.5, width: 800, height: 600))
        // 허용하지 않는 명령과 판단할 수 없는 값 → nil(호출자는 .notResizable).
        expectFrame("relative shrink (right) is not allowed", place(rightHalf, anchor: .right), nil)
        expectFrame("relative shrink (bottom) is not allowed", place(rightHalf, anchor: .bottom), nil)
        expectFrame("undo (topLeft) is not allowed", place(rightHalf, anchor: .topLeft), nil)
        expectFrame("unknown work area", place(rightHalf, area: nil), nil)
        expectFrame("zero size", place(rightHalf, size: .zero), nil)
        expectFrame("NaN target", place(CGRect(x: CGFloat.nan, y: 25, width: 960, height: 1055)), nil)
        expectFrame("NaN work area", place(rightHalf, area: CGRect(x: 0, y: 25, width: CGFloat.nan, height: 1055)), nil)

        testFixedSizeDecision()
        testFixedSizeQueryOrder()
        testFixedSizeSnapSequence()
    }

    // #167: writer가 size 권한 답을 넘기면 그대로 / 위치만 / 실패 중 무엇을 할지. 조회 실패는 잠김의 증거가 아니다.
    static func testFixedSizeDecision() {
        let current = CGRect(x: 300, y: 200, width: 800, height: 600)
        let leftHalf = FrameCalculator.halfRect(.left, workArea: workArea)
        let parked = CGRect(x: 0, y: 252.5, width: 800, height: 600)
        func decide(
            _ answer: SettableAnswer, requested: CGRect = leftHalf, anchor: FrameAnchor = .workAreaEdges,
            area: CGRect? = workArea
        ) -> FixedSizeWriteDecision {
            FixedSizePlacementPolicy.decide(
                anchor: anchor, current: current, requested: requested, workArea: area, sizeSettable: answer
            )
        }
        func expectDecision(_ label: String, _ got: FixedSizeWriteDecision, _ want: FixedSizeWriteDecision) {
            checks += 1
            if got != want {
                failures += 1
                print("FAIL \(label): got \(got) want \(want)")
            }
        }
        expectDecision("resizable window writes the request as is", decide(.settable), .proceed)
        expectDecision("locked size moves only", decide(.notSettable), .retarget(parked))
        // 이것을 실패시키는 것: .unknown을 .notSettable과 같은 arm에 두면 retarget(parked)가 나온다 —
        // 타임아웃 난 크기 조절 가능 창이 위치만 옮겨지고 조용히 성공하던 결함.
        expectDecision("a failed settable query keeps .notResizable", decide(.unknown), .fail(.notResizable))
        expectDecision("relative shrink on a locked size still fails",
                       decide(.notSettable, anchor: .right), .fail(.notResizable))
        expectDecision("unknown work area on a locked size fails",
                       decide(.notSettable, area: nil), .fail(.notResizable))
        // 크기가 안 바뀌는 요청(Move)은 답과 무관하게 그대로 — writer는 이때 size를 묻지도 않는다.
        // 이것을 실패시키는 것: resizesSize 가드를 지우면 Move가 .unknown에서 실패한다.
        let moveOnly = CGRect(x: 1100, y: 200, width: 800, height: 600)
        expectDecision("move-only request ignores a failed query", decide(.unknown, requested: moveOnly), .proceed)
        expectDecision("move-only request ignores a locked size", decide(.notSettable, requested: moveOnly), .proceed)
    }

    // #167: 쓰기 전 AX 권한 조회의 여부와 순서. 클로저가 호출을 기록한다.
    static func testFixedSizeQueryOrder() {
        // AX 조회 결과 → 답. 이것을 실패시키는 것: init을 `querySucceeded && settable ? .settable : .notSettable`로
        // 합치면 조회 실패가 잠김이 되어(1번 결함) 아래 첫 케이스가 .notSettable을 낸다.
        expectName("failed query is unknown", "\(SettableAnswer(querySucceeded: false, settable: false))", "unknown")
        expectName("failed query ignores the flag",
                   "\(SettableAnswer(querySucceeded: false, settable: true))", "unknown")
        expectName("answered settable", "\(SettableAnswer(querySucceeded: true, settable: true))", "settable")
        expectName("answered not settable", "\(SettableAnswer(querySucceeded: true, settable: false))", "notSettable")

        final class CallLog { var calls: [String] = [] }
        let topLeft = CGRect(x: 0, y: 25, width: 800, height: 600)
        let floating = CGRect(x: 300, y: 200, width: 800, height: 600)
        let leftHalf = FrameCalculator.halfRect(.left, workArea: workArea)
        func run(
            current: CGRect, requested: CGRect, movable: Bool = true, size: SettableAnswer = .settable
        ) -> (FixedSizeWriteDecision, [String]) {
            let log = CallLog()
            let queries = SettableQueries(
                positionSettable: { log.calls.append("position"); return movable },
                sizeSettable: { log.calls.append("size"); return size }
            )
            let decision = FixedSizePlacementPolicy.resolve(
                anchor: .workAreaEdges, current: current, requested: requested, workArea: workArea, queries: queries
            )
            return (decision, log.calls)
        }
        func expectRun(_ label: String, _ got: (FixedSizeWriteDecision, [String]),
                       _ decision: FixedSizeWriteDecision, _ calls: [String]) {
            checks += 1
            if got.0 != decision || got.1 != calls {
                failures += 1
                print("FAIL \(label): got \(got.0) \(got.1) want \(decision) \(calls)")
            }
        }
        let moveOnly = CGRect(x: 1100, y: 200, width: 800, height: 600)
        let grow = CGRect(x: 300, y: 200, width: 1000, height: 700)
        expectRun("no-op asks nothing", run(current: floating, requested: floating), .proceed, [])
        expectRun("move only asks position only", run(current: floating, requested: moveOnly), .proceed, ["position"])
        expectRun("resize only asks size only", run(current: floating, requested: grow), .proceed, ["size"])
        // 이것을 실패시키는 것: size를 position보다 먼저 물으면 순서가 ["size", "position"]이 된다.
        expectRun("move + resize asks position, then size",
                  run(current: floating, requested: leftHalf), .proceed, ["position", "size"])
        // 이것을 실패시키는 것: position 실패 뒤에도 size를 물으면 ["position", "size"]가 된다.
        expectRun("immovable window never asks size",
                  run(current: floating, requested: leftHalf, movable: false), .fail(.notMovable), ["position"])
        let centered = CGRect(x: 560, y: 252.5, width: 800, height: 600)
        // 이미 좌상단에 있는 창에 Maximize: 원래 요청은 크기만 바꾸지만, 위치만으로 낮춘 frame은 위치를 바꾼다.
        // 이것을 실패시키는 것: 재확인을 지우면 ["size"]에서 멈추고 움직일 수 없는 창에 .retarget이 나온다.
        expectRun("resize-only fallback that moves asks position once",
                  run(current: topLeft, requested: workArea, size: .notSettable), .retarget(centered),
                  ["size", "position"])
        expectRun("resize-only fallback on an immovable window fails",
                  run(current: topLeft, requested: workArea, movable: false, size: .notSettable),
                  .fail(.notMovable), ["size", "position"])
        // 이것을 실패시키는 것: `!movesRequested` 조건을 지우면 position을 두 번 묻는다.
        expectRun("fallback after a moving request does not ask position again",
                  run(current: floating, requested: leftHalf, size: .notSettable),
                  .retarget(CGRect(x: 0, y: 252.5, width: 800, height: 600)), ["position", "size"])
        // 작업영역보다 큰 창이 이미 좌상단: 원래 요청도 대체 frame도 위치를 안 바꾼다 → position을 묻지 않는다.
        // 이것을 실패시키는 것: 재확인 조건에서 movesNow를 지우면 ["size", "position"]이 된다.
        let oversized = CGRect(x: 0, y: 25, width: 2000, height: 1200)
        expectRun("fallback that stays in place asks size only",
                  run(current: oversized, requested: workArea, size: .notSettable), .retarget(oversized), ["size"])
        expectRun("failed size query keeps .notResizable",
                  run(current: floating, requested: leftHalf, size: .unknown),
                  .fail(.notResizable), ["position", "size"])
    }

    // #167: 크기 고정 창의 snapThrow 두 번 — 첫 입력이 스냅을 기록하고, 두 번째 입력이 옆 모니터로 던진다.
    // writer 결과에서 결과 정책 입력을 만드는 init(`CommandOutcome(pre:applied:snappedEdge:)`)까지 거친다.
    static func testFixedSizeSnapSequence() {
        let leftHalf = FrameCalculator.halfRect(.left, workArea: workArea)
        let parked = CGRect(x: 0, y: 252.5, width: 800, height: 600)
        let adjacent = adjacentArea(.left)
        // 창이 이미 대체 위치에 있다(예: 지난 실행에서 옮겼고 스냅 기록은 없음). writer는 쓰지 않고 성공한다.
        let first = plan(.snapThrow(.left), current: parked, adjacent: adjacent)
        expectPlan("first press plans the half (no record yet)",
                   first, CommandPlan(target: leftHalf, snappedEdge: .left))
        guard case let .retarget(aimed) = FixedSizePlacementPolicy.decide(
            anchor: WindowCommand.snapThrow(.left).frameAnchor, current: parked, requested: first.target,
            workArea: workArea, sizeSettable: .notSettable
        ) else {
            checks += 1
            failures += 1
            print("FAIL fixed-size snap: expected a retarget")
            return
        }
        expect("fallback aims at where the window already is", aimed, parked)
        let applied = FrameApplyResult(target: aimed, achieved: parked, error: nil, mayHaveMutated: false)
        // 이것을 실패시키는 것: init이 applied.target 대신 다른 값(plan의 반쪽 등)을 target으로 쓰면 무시된 쓰기로
        // 보여 .keep이 되고, 아래 두 번째 입력이 던지지 않고 다시 스냅한다.
        let decision = CommandOutcomePolicy.decide(
            CommandOutcome(pre: parked, applied: applied, snappedEdge: first.snappedEdge)
        )
        expectDecision("already-in-place fixed-size window records the snap",
                       decision, OutcomeDecision(recordUndo: false, snap: .record(.left, frame: parked)))
        guard case let .record(edge, frame) = decision.snap else { return }
        let second = plan(.snapThrow(.left), current: parked, recorded: SnapRecord(edge: edge, frame: frame),
                          adjacent: adjacent)
        expectPlan("second press throws to the adjacent display", second,
                   CommandPlan(target: FrameCalculator.halfRect(.right, workArea: adjacent), snappedEdge: .right))
        // init이 결과 값을 빠짐없이 옮기는지. target과 achieved가 다른 케이스여야 둘을 바꿔 쓴 배선이 잡힌다.
        // 이것을 실패시키는 것: init이 target에 achieved를 넣으면 앱이 무시한 쓰기가 의도된 no-op으로 보여 스냅이 기록된다.
        let floating = CGRect(x: 300, y: 200, width: 800, height: 600)
        let ignored = FrameApplyResult(target: parked, achieved: floating, error: nil, mayHaveMutated: true)
        expectDecision("ignored fixed-size write records nothing",
                       CommandOutcomePolicy.decide(CommandOutcome(pre: floating, applied: ignored, snappedEdge: .left)),
                       OutcomeDecision(recordUndo: false, snap: .keep))
        // 이것을 실패시키는 것: init이 error를 버리면(failed: false) 부분 적용이 스냅 완료로 기록된다.
        let partial = CGRect(x: 0, y: 200, width: 800, height: 600)
        let partialApply = FrameApplyResult(
            target: parked, achieved: partial, error: .applyFailed, mayHaveMutated: true
        )
        expectDecision("partially applied fixed-size write clears the snap",
                       CommandOutcomePolicy.decide(
                           CommandOutcome(pre: floating, applied: partialApply, snappedEdge: .left)
                       ),
                       OutcomeDecision(recordUndo: true, snap: .clear))
        let failedApply = FrameApplyResult(target: aimed, achieved: nil, error: .applyFailed, mayHaveMutated: true)
        expectDecision("failed fixed-size write keeps a restore point and clears the snap",
                       CommandOutcomePolicy.decide(
                           CommandOutcome(pre: parked, applied: failedApply, snappedEdge: .left)
                       ),
                       OutcomeDecision(recordUndo: true, snap: .clear))
    }

    // #100: 모든 크기 쓰기 뒤의 실제 frame으로, 작업영역 모서리에 닿아야 할 창을 그 모서리로 다시 붙인다.
    static func testEdgeReanchor() {
        let rightHalf = CGRect(x: 960, y: 25, width: 960, height: 1055)
        func reanchor(
            _ achieved: CGRect, target: CGRect = rightHalf, anchor: FrameAnchor = .workAreaEdges,
            area: CGRect? = workArea, elapsed: TimeInterval = 0.1
        ) -> CGPoint? {
            EdgeReanchorPolicy.correctedOrigin(EdgeReanchorInput(
                anchor: anchor, target: target, workArea: area, achieved: achieved,
                sizeTolerance: FrameApply.sizeTolerance, originTolerance: FrameApply.originTolerance,
                elapsed: elapsed, budget: 1
            ))
        }
        func expectOrigin(_ label: String, _ got: CGPoint?, _ want: CGPoint?) {
            checks += 1
            let same = switch (got, want) {
            case (nil, nil): true
            case let (got?, want?): approx(got.x, want.x) && approx(got.y, want.y)
            default: false
            }
            if !same {
                failures += 1
                print("FAIL \(label): got \(String(describing: got)) want \(String(describing: want))")
            }
        }
        // 이슈의 재현값: 최대 폭 700인 앱에 Right 1/2 → 오른쪽 여백 260 대신 모서리에 붙는다.
        expectOrigin("undersized right half hugs the right edge",
                     reanchor(CGRect(x: 960, y: 25, width: 700, height: 1055)), CGPoint(x: 1220, y: 25))
        expectOrigin("reached target needs nothing",
                     reanchor(rightHalf), nil)
        // 허용오차 8pt: 한 셀 모자란 터미널은 옮기지 않는다(엄격한 초과).
        expectOrigin("7pt short stays", reanchor(CGRect(x: 960, y: 25, width: 953, height: 1055)), nil)
        expectOrigin("exactly 8pt short stays", reanchor(CGRect(x: 960, y: 25, width: 952, height: 1055)), nil)
        expectOrigin("9pt short moves", reanchor(CGRect(x: 960, y: 25, width: 951, height: 1055)),
                     CGPoint(x: 969, y: 25))
        // #37 현장 기록(L자 구성, 2880 폭): 목표보다 큰 앱도 같은 규칙으로 모서리를 지킨다.
        let wide = CGRect(x: -824, y: -1589, width: 2880, height: 1589)
        expectOrigin("oversized right half keeps the right edge",
                     reanchor(CGRect(x: 616, y: -1589, width: 1464, height: 1589),
                              target: CGRect(x: 616, y: -1589, width: 1440, height: 1589), area: wide),
                     CGPoint(x: 592, y: -1589))
        // 두 모서리에 모두 닿는 목표(최대화)는 좌상단 고정 — 여기서 옮기지 않는다.
        expectOrigin("undersized maximize keeps top-left",
                     reanchor(CGRect(x: 0, y: 25, width: 1500, height: 900), target: workArea), nil)
        expectOrigin("undersized left half is already at its edge",
                     reanchor(CGRect(x: 0, y: 25, width: 700, height: 1055),
                              target: CGRect(x: 0, y: 25, width: 960, height: 1055)), nil)
        let bottomHalf = FrameCalculator.halfRect(.bottom, workArea: workArea)
        expectOrigin("undersized bottom half hugs the bottom edge",
                     reanchor(CGRect(x: 0, y: bottomHalf.minY, width: 1920, height: 400), target: bottomHalf),
                     CGPoint(x: 0, y: 680))
        // 이미 보정된 자리면 다시 쓰지 않는다(2pt 안).
        expectOrigin("already at the corrected origin",
                     reanchor(CGRect(x: 1221, y: 25, width: 700, height: 1055)), nil)
        // origin 허용오차 2pt(엄격한 초과)와 크기가 큰 쪽의 8pt 경계.
        expectOrigin("exactly 2pt off the corrected origin stays",
                     reanchor(CGRect(x: 1222, y: 25, width: 700, height: 1055)), nil)
        expectOrigin("3pt off the corrected origin moves",
                     reanchor(CGRect(x: 1223, y: 25, width: 700, height: 1055)), CGPoint(x: 1220, y: 25))
        expectOrigin("exactly 8pt oversize stays",
                     reanchor(CGRect(x: 960, y: 25, width: 968, height: 1055)), nil)
        expectOrigin("9pt oversize moves", reanchor(CGRect(x: 960, y: 25, width: 969, height: 1055)),
                     CGPoint(x: 951, y: 25))
        // 판단할 수 없는 값·상황은 손대지 않는다.
        expectOrigin("zero width", reanchor(CGRect(x: 960, y: 25, width: 0, height: 1055)), nil)
        expectOrigin("NaN width", reanchor(CGRect(x: 960, y: 25, width: CGFloat.nan, height: 1055)), nil)
        expectOrigin("negative height", reanchor(CGRect(x: 960, y: 25, width: 700, height: -5)), nil)
        expectOrigin("unknown work area", reanchor(CGRect(x: 960, y: 25, width: 700, height: 1055), area: nil), nil)
        expectOrigin("budget spent (boundary counts as spent)",
                     reanchor(CGRect(x: 960, y: 25, width: 700, height: 1055), elapsed: 1), nil)
        let short = CGRect(x: 960, y: 25, width: 700, height: 1055)
        expectOrigin("invalid target", reanchor(short, target: CGRect(x: 960, y: 25, width: 0, height: 1055)), nil)
        expectOrigin("invalid work area", reanchor(short, area: CGRect(x: 0, y: 25, width: CGFloat.nan, height: 1055)), nil)
        func reanchor(_ achieved: CGRect, originTolerance: CGFloat) -> CGPoint? {
            EdgeReanchorPolicy.correctedOrigin(EdgeReanchorInput(
                anchor: .workAreaEdges, target: rightHalf, workArea: workArea, achieved: achieved,
                sizeTolerance: FrameApply.sizeTolerance, originTolerance: originTolerance, elapsed: 0.1, budget: 1
            ))
        }
        expectOrigin("NaN origin tolerance", reanchor(short, originTolerance: CGFloat.nan), nil)
        expectOrigin("negative origin tolerance", reanchor(short, originTolerance: -1), nil)
        for anchor in [FrameAnchor.topLeft, .right, .bottom] {
            expectOrigin("anchor \(anchor) is not edge-reanchored",
                         reanchor(CGRect(x: 960, y: 25, width: 700, height: 1055), anchor: anchor), nil)
        }
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

    /// 재시도 판정. 예산의 기준점이 **명령 시작**이라는 것이 이 PR 의 핵심이고, 예산 초과 경로는
    /// 응답이 느린 앱을 재현해야만 밟히던 곳이라 값으로 내려야 검증된다(감사 H-3).
    static func testWriteRetryPolicy() {
        let budget = AXMessagingTimeout.writeRetryBudget(for: AXMessagingTimeout.resolve)

        func decide(_ elapsed: TimeInterval, _ reached: Bool?, moves: Bool = true, resizes: Bool = true)
            -> WriteRetryDecision {
            WriteRetryPolicy.decide(WriteRetryInput(
                elapsed: elapsed, budget: budget, reachedTarget: reached, moves: moves, resizes: resizes
            ))
        }

        // 검증 읽기 실패 → 창이 어디 있는지 모른다. 또 쓰지 않는다.
        expectName("unknown result does not retry", "\(decide(0, nil).shouldRetry)", "false")
        // 이미 도달 → 재시도는 낭비.
        expectName("reached target does not retry", "\(decide(0, true).shouldRetry)", "false")
        // 미달 + 예산 이내 → 바뀌는 축만.
        expectName("moves only retries position", "\(decide(0, false, moves: true, resizes: false))",
                   "\(WriteRetryDecision(retryPosition: true, retrySize: false))")
        expectName("resizes only retries size", "\(decide(0, false, moves: false, resizes: true))",
                   "\(WriteRetryDecision(retryPosition: false, retrySize: true))")
        expectName("both axes retry both", "\(decide(0, false))",
                   "\(WriteRetryDecision(retryPosition: true, retrySize: true))")
        // 둘 다 아니면 쓸 것이 없다(apply 의 no-op 가드 때문에 실호출로는 안 오지만 순수 함수라 방어).
        expectName("no axis, no retry", "\(decide(0, false, moves: false, resizes: false).shouldRetry)", "false")
        // 예산 초과 → 생략. 이것이 느린 앱에서 프리즈를 키우지 않는 가드다.
        expectName("over budget does not retry", "\(decide(budget + 0.1, false).shouldRetry)", "false")
        // 경계: 정확히 예산이면 초과로 본다(`<` 비교). `<=` 로 바꾸면 이 검사가 잡는다.
        expectName("exactly at budget does not retry", "\(decide(budget, false).shouldRetry)", "false")
        // 예산 직전은 재시도한다 — 위 두 행이 "항상 false"로 통과하는 것을 막는다.
        expectName("just under budget retries", "\(decide(budget - 0.01, false).shouldRetry)", "true")
    }

    /// 재시도 예산 값. 공식으로 단정하면 항진명제라 리터럴로 고정한다(PR #119 의 resolveBudget 과 같은 이유).
    static func testWriteRetryBudget() {
        expectName("quick write-retry budget", "\(AXMessagingTimeout.writeRetryBudget(for: 0.25))", "5.0")
        expectName("balanced write-retry budget", "\(AXMessagingTimeout.writeRetryBudget(for: 0.5))", "5.0")
        expectName("patient write-retry budget", "\(AXMessagingTimeout.writeRetryBudget(for: 1.0))", "8.0")
        // Quick 이 Balanced 와 **같다**는 것이 해석 예산 바닥(3초)이 살아 있다는 증거다. 바닥이 사라지면
        // Quick 은 3.5 가 된다 — 불변식 `writeRetryBudget > resolveBudget` 은 그래도 통과하므로 여기서 잡는다.
        let quick = AXMessagingTimeout.writeRetryBudget(for: 0.25)
        expectName("quick equals balanced (floor holds)",
                   "\(quick == AXMessagingTimeout.writeRetryBudget(for: 0.5))", "true")
        // 쓰기 몫이 남아 있어야 재시도가 죽지 않는다.
        for timeout in [Float(0.25), 0.5, 1.0] {
            let retryBudget = AXMessagingTimeout.writeRetryBudget(for: timeout)
            let over = retryBudget > AXMessagingTimeout.resolveBudget(for: timeout)
            expectName("write-retry budget exceeds resolve budget at \(timeout)", "\(over)", "true")
        }
    }
}
