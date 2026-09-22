//
//  FrameWriteRequest.swift
//  Azimuth
//
//  한 번의 frame 쓰기에 필요한 값 묶음. 파라미터로 흘리지 않고 묶는 이유는 `CommandOutcome`·
//  `CommandPlanInput` 과 같다 — 다섯 개면 이미 SwiftLint 상한이라 여유가 0이다.
//
//  `AXUIElement` 를 운반하는 `ResolvedWindow` 를 담으므로 하네스에 넣을 수 없다. 이 요청으로 내리는
//  **판단**(재시도 여부)만 `Commands/WriteRetryPolicy` 로 빼서 테스트한다.
//

import CoreGraphics

@MainActor
struct FrameWriteRequest {
    /// 창을 놓으려는 frame(AX 좌표).
    let target: CGRect
    /// 해석 단계가 만든 창 정보(element·appElement·pid·현재 frame).
    let resolved: ResolvedWindow
    /// anchor 보정 기준 작업영역. undo 는 직전 frame 복원이라 nil.
    let workArea: CGRect?
    /// 고정하려는 모서리 의도.
    let anchor: FrameAnchor
    /// **명령이 시작된 시각**(`ProcessInfo.processInfo.systemUptime`). 재시도 예산은 이 시각부터 잰다 —
    /// 쓰기 함수 진입 시각이 아니다. 해석·권한 확인·억제에 쓴 시간이 예산에 포함되어야, 느린 앱에서
    /// 추가 쓰기로 프리즈를 늘리지 않는다는 가드가 실제로 작동한다(감사 H-3).
    let startedAt: CFTimeInterval

    /// 창의 현재 frame(AX 좌표). `resolved` 가 운반하는 값이라 따로 받지 않는다.
    var current: CGRect {
        resolved.frame.rect
    }
}
