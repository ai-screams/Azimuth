//
//  UndoHistory.swift
//  Azimuth
//
//  창 하나의 Undo 기록 — 최근 frame을 오래된 것부터 최근 것 순으로 쌓는 깊이 제한 스택(#170).
//
//  왜 따로 있나: `WindowUndoStore`는 `AXUIElement`를 키로 들고 있어 하네스에서 만들 수 없다. 깊이 규칙
//  (push, 상한 초과 시 오래된 것부터 버리기, pop, 설정을 줄였을 때 자르기)은 값만으로 정해지므로 여기로 빼서
//  `make test`로 검증한다. 저장소는 창마다 이 값을 하나씩 들고 있기만 한다.
//
//  순수 로직 파일 — AppKit/AX를 import하지 않는다(Commands/AGENTS.md). scripts/harness-sources.sh에 있다.
//

import CoreGraphics

nonisolated struct UndoHistory: Equatable {
    /// 창 하나가 기억할 단계 수. 1이면 예전처럼 직전 frame 하나만 기억한다.
    static let depth = BoundedIntSetting(range: 1 ... 20, defaultValue: 5)
    /// 기록을 들고 있을 창 수(`WindowUndoStore`, LRU). 기본 64는 설정이 생기기 전의 고정값이다. 최대(256창 × 20단계)여도
    /// frame 하나가 32바이트라 약 160KB다.
    static let windowCapacity = BoundedIntSetting(range: 1 ... 256, defaultValue: 64)

    /// 오래된 것 → 최근 것.
    private(set) var frames: [CGRect] = []

    /// 다음 Undo가 복원할 frame. 비었으면 nil.
    var latest: CGRect? {
        frames.last
    }

    var isEmpty: Bool {
        frames.isEmpty
    }

    /// 명령이 창을 바꾸기 직전 frame을 쌓는다. 깊이를 넘으면 가장 오래된 것부터 버린다.
    mutating func push(_ frame: CGRect, depth: Int) {
        frames.append(frame)
        trim(to: depth)
    }

    /// Undo가 `latest`에 도달했을 때 그것을 버린다 — 다음 Undo는 그 이전 frame으로 간다.
    mutating func popLatest() {
        _ = frames.popLast()
    }

    /// 깊이를 넘는 오래된 frame을 버린다. 설정에서 깊이를 줄이면 다음 접근에서 바로 반영된다.
    mutating func trim(to depth: Int) {
        let excess = frames.count - Self.depth.clamped(depth)
        if excess > 0 { frames.removeFirst(excess) }
    }
}
