//
//  CommandFeedbackPolicy.swift
//  Azimuth
//
//  명령 실행 결과 + 사용자 설정 + 세션 상태 → 사용자에게 무엇을 보일지. 값 in / 값 out 이다.
//
//  뷰가 아니라 여기서 정하는 이유: 이 판단 하나가 관측 가능한 결과 다섯 개를 좌우하는데
//  (마지막 실패 표시·침묵·비프·알림·권한 안내) 전부 AppKit 호출 옆에 섞여 있어 테스트가 닿지 못했다.
//  `CommandOutcomePolicy`(AX 결과 → Undo/Snap 커밋)와 같은 패턴이다.
//
//  ⚠️ 순수 로직 파일 — AppKit/AX를 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//

import Foundation

/// 상태바 메뉴의 "마지막 실패" 행을 어떻게 할지.
nonisolated enum LastFailureAction: Equatable {
    /// 성공했으므로 지운다.
    case clear
    /// 그대로 둔다. 조용한 스킵에서 쓴다 — 아무것도 성공하지 않았는데 지우면
    /// **일어나지 않은 성공**을 주장하는 셈이다.
    case keep
    case set(message: String)
}

nonisolated struct CommandFeedback: Equatable {
    let lastFailure: LastFailureAction
    let beep: Bool
    let notify: Bool
    /// 권한 안내(설정창)를 띄울지. 세션 플래그를 세우고 창을 여는 것은 호출자 몫이다 —
    /// 세션 상태는 정책이 아니라 앱이 소유한다.
    let nudgeForPermission: Bool
}

nonisolated enum CommandFeedbackPolicy {
    /// `error == nil`이면 성공. `Result<Void, _>`를 받지 않는 이유는 `Void`가 Equatable이 아니라
    /// 표 기반 테스트에서 입력을 값으로 다루기 불편해서다.
    ///
    /// 권한 안내 판정에 `AccessibilityPermissionService`를 **읽지 않는다.** 그 캐시는 무효화 지점이
    /// 둘뿐인데(앱 활성화·메뉴 열기) 안내가 필요한 순간은 정확히 그 둘 다 일어나지 않은 때라,
    /// 캐시를 보면 정작 필요할 때 안내가 건너뛰어졌다. 에러가 더 신선한 증거다.
    static func decide(
        error: WindowCommandError?,
        soundEnabled: Bool,
        notifyEnabled: Bool,
        alreadyNudgedThisSession: Bool
    ) -> CommandFeedback {
        guard let error else {
            return CommandFeedback(lastFailure: .clear, beep: false, notify: false, nudgeForPermission: false)
        }
        // exhaustive — `default:`를 두지 않는다. 새 에러 케이스가 조용히 "기타"로 빨려 들어가면,
        // 그 케이스가 사용자에게 어떻게 보일지 아무도 결정하지 않은 채 출시된다.
        switch error {
        case .transient:
            // Space 전환·애니메이션 중의 순간적 실패. 다시 누르면 되므로 성가시게 하지 않는다.
            return CommandFeedback(lastFailure: .keep, beep: false, notify: false, nudgeForPermission: false)
        case .resolution(.permissionDenied):
            return CommandFeedback(
                lastFailure: .set(message: error.userFacingMessage),
                beep: soundEnabled,
                notify: notifyEnabled,
                nudgeForPermission: !alreadyNudgedThisSession
            )
        case .resolution, .workAreaUnavailable, .notMovable, .notResizable, .applyFailed, .noUndoState,
             .resolveBudgetExceeded:
            // 같은 처리를 받는 케이스를 한 arm으로 묶는다 — exhaustive 성질(새 케이스가 생기면
            // 빌드가 깨진다)은 유지하면서 순환복잡도를 경고선 쪽으로 밀지 않는다.
            //
            // `.resolveBudgetExceeded`가 여기 있는 이유: 앱이 일관되게 느려 해석이 예산을 넘긴
            // 상태는 다시 눌러도 재현된다. `.transient`처럼 조용히 넘기면 사용자는 명령이 왜
            // 듣지 않는지 알 길이 없다.
            return CommandFeedback(
                lastFailure: .set(message: error.userFacingMessage),
                beep: soundEnabled,
                notify: notifyEnabled,
                nudgeForPermission: false
            )
        }
    }
}
