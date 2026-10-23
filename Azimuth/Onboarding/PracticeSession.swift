//
//  PracticeSession.swift
//  Azimuth
//
//  연습 창 안내(#176)의 단계와 판정. 연습 창은 Azimuth 자신의 창이라 AX 명령 경로(자기 창 제외)를 타지 않고,
//  연습 창이 앞에 있을 때 받은 단축키를 같은 기하(`FrameCalculator`)로 직접 옮긴다. 여기서는 값만 다룬다:
//  명령 하나에 연습 창이 갈 곳, 이전 위치 기록(Undo), 실제로 옮겨진 뒤 이번 단계를 마쳤는지.
//  모든 사각형은 AX 좌표(좌상단 원점)다.
//

import CoreGraphics

nonisolated enum PracticeStep: Int, CaseIterable {
    case leftHalf
    case maximize
    case undo
    case done

    /// 이 단계에서 눌러 볼 명령. 완료 단계는 없다.
    var command: WindowCommand? {
        switch self {
        case .leftHalf:
            .snapThrow(.left)
        case .maximize:
            .maximize
        case .undo:
            .undo
        case .done:
            nil
        }
    }

    /// 할 일 단계의 개수("Try it · N of 3"의 3).
    static let tryCount = allCases.count - 1
}

nonisolated struct PracticeSession: Equatable {
    /// 실제 창이 목표와 이만큼 어긋나도 닿은 것으로 본다(창 최소 크기·반올림).
    static let reachTolerance: CGFloat = 2
    /// Undo 기록 상한. 연습에는 몇 번이면 충분하고, 끝없이 쌓이지 않게 한다.
    static let historyLimit = 20

    private(set) var step: PracticeStep = .leftHalf
    private(set) var history: [CGRect] = []

    /// 명령 하나를 받았을 때 연습 창이 갈 곳. nil이면 움직이지 않는다(되돌릴 기록 없는 Undo, 디스플레이 이동).
    /// 실제로 자리가 바뀌는 이동만 Undo 기록에 남긴다.
    mutating func target(for command: WindowCommand, current: CGRect, workArea: CGRect) -> CGRect? {
        if command == .undo { return history.popLast() }
        if case .moveToDisplay = command { return nil }
        let target = FrameCalculator.targetFrame(for: command, current: current, workArea: workArea)
        if target != current {
            history.append(current)
            if history.count > Self.historyLimit { history.removeFirst() }
        }
        return target
    }

    /// 창을 옮긴 뒤 실제 위치로 판정한다. 이번 단계의 명령이고 목표에 닿았으면 다음 단계로 가고 true.
    mutating func didMove(_ command: WindowCommand, target: CGRect, actual: CGRect) -> Bool {
        guard command == step.command, Self.isReached(actual: actual, target: target) else { return false }
        step = PracticeStep(rawValue: step.rawValue + 1) ?? .done
        return true
    }

    static func isReached(actual: CGRect, target: CGRect) -> Bool {
        let edges = [
            (actual.minX, target.minX), (actual.minY, target.minY),
            (actual.maxX, target.maxX), (actual.maxY, target.maxY)
        ]
        return edges.allSatisfy { abs($0.0 - $0.1) <= reachTolerance }
    }
}
