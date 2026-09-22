//
//  WriteRetryPolicy.swift
//  Azimuth
//
//  "검증에서 목표에 못 미쳤을 때 한 번 더 쓸 것인가"만 담당하는 순수 결정 계층.
//  지금까지 이 판단은 AX 호출 사이에 섞여 있어 테스트가 닿지 못했다 — 특히 예산 초과 경로는
//  응답이 느린 앱을 재현해야만 밟을 수 있어 사실상 검증 불가였다(감사 H-3).
//
//  예산의 기준점이 핵심이다. 이전에는 쓰기 함수에 **진입한 시각**부터 쟀는데, 그 앞에서 이미
//  권한·settable 확인과 애니메이션 억제로 AX 왕복이 여러 번 일어난다. 느린 앱일수록 그 앞구간이
//  길어지므로, "프리즈를 키우지 않으려는" 가드가 정작 프리즈가 심할 때 통과했다. 그래서 경과는
//  **명령이 시작된 시각** 기준으로 받는다.
//
//  순수 로직 파일 — AppKit/AX를 import하지 않는다(계층 규율, Commands/AGENTS.md). Foundation만 사용.
//  새 순수 파일은 scripts/harness-sources.sh 에 추가해야 하네스가 컴파일한다.
//

import Foundation

/// 재시도 판정에 필요한 값 전부.
nonisolated struct WriteRetryInput: Equatable {
    /// **명령이 시작된 시각** 이후 경과(초). 쓰기 함수 진입 이후가 아니다.
    let elapsed: TimeInterval
    /// 이 경과의 상한(`AXMessagingTimeout.writeRetryBudget(for:)`).
    let budget: TimeInterval
    /// 검증 읽기 결과: 목표에 도달했으면 true, 미달이면 false, **읽기 자체가 실패했으면 nil**.
    let reachedTarget: Bool?
    /// 이 명령이 origin을 바꾸는가.
    let moves: Bool
    /// 이 명령이 size를 바꾸는가.
    let resizes: Bool
}

nonisolated struct WriteRetryDecision: Equatable {
    let retryPosition: Bool
    let retrySize: Bool

    var shouldRetry: Bool {
        retryPosition || retrySize
    }

    static let none = WriteRetryDecision(retryPosition: false, retrySize: false)
}

nonisolated enum WriteRetryPolicy {
    static func decide(_ input: WriteRetryInput) -> WriteRetryDecision {
        // 결과를 읽지 못했다면 창이 어디 있는지 모른다. 모르는 상태에서 또 쓰면 그 쓰기가 무엇을
        // 고쳤는지도 알 수 없다 — 판단 근거가 생길 때까지 손을 뗀다.
        guard let reachedTarget = input.reachedTarget else { return .none }
        // 이미 도달했으면 재시도는 순수한 낭비다(AX 왕복 + 창 재배치).
        guard !reachedTarget else { return .none }
        // 여기까지 오는 데 예산을 다 썼다면 앱이 심하게 느리다는 뜻이다. 추가 쓰기로 MainActor
        // 프리즈를 늘리지 않는다(감사 H-3). 경계값(정확히 예산)도 초과로 본다.
        guard input.elapsed < input.budget else { return .none }
        // 바뀌는 축만 다시 쓴다 — 이동만이면 size를, 리사이즈만이면 position을 건드리지 않는다(감사 M-3).
        return WriteRetryDecision(retryPosition: input.moves, retrySize: input.resizes)
    }
}
