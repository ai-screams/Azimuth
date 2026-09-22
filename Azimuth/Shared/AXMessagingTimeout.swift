//
//  AXMessagingTimeout.swift
//  Azimuth
//
//  AX messaging timeout 정책. **값과 그 사이의 불변식**을 한곳에 모은다.
//  적용(누가 언제 거는가)은 나뉜 채로 둔다 — timeout은 element 단위라 해석 진입에서 한 번,
//  쓰기 진입에서 한 번 거는 것이 자연스럽다. 합쳐야 하는 것은 메커니즘이 아니라 값이다.
//
//  ⚠️ 순수 파일 — AppKit/AX를 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//  Foundation은 허용된다(`Commands/ShortcutListPolicy`도 Foundation만 쓴다). TimeInterval이
//  Foundation 타입이라 없으면 "cannot find type in scope"로 하네스 컴파일이 깨진다.
//  두 값의 대소 관계가 설계의 전제라서, 떨어져 있으면 한쪽만 바꿔도 컴파일이 통과해 버린다.
//  그래서 하네스에 넣고 `make test`가 불변식을 검사하게 했다.
//

import Foundation

nonisolated enum AXMessagingTimeout {
    /// 해석 단계 상한(초). 창을 아직 건드리지 않는 읽기뿐이고, 실패가 `.appUnresponsive`
    /// (비프 + 상태바 사유 행)로 **사용자 눈에 보이므로** 짧게 둔다. 명령당 해석 읽기가
    /// 6~8회라 이 값이 그만큼 곱해진다 — 응답 없는 앱에서 최악 정지의 주된 항이었다.
    ///
    /// 동종 윈도우 매니저 실측: alt-tab-macos는 같은 포커스 창 읽기에 0.25초, 전역 상한 1초.
    static let resolve: Float = 0.5

    /// position/size 쓰기 단계 상한(초). 쓰기 타임아웃은 `WindowFrameWriter.applyError`에서
    /// `.cannotComplete` → `.transient`(비프도 메뉴 노출도 없는 **조용한 스킵**)으로 매핑되므로,
    /// 굼뜬 앱에서 명령이 소리 없이 무시되지 않도록 넉넉히 둔다.
    ///
    /// **`resolve` 이상이어야 한다.** 이 값을 내리면 `WindowFrameWriter`의 상향이 이름과 반대로
    /// 상한을 *내리는* 동작이 되고, 조용한 스킵을 피하려던 목적이 정확히 뒤집힌다. 컴파일 에러는
    /// 나지 않으므로 `CommandEngineTests.testMessagingTimeoutPolicy`가 대신 잡는다.
    static let write: Float = 2.0

    /// 사용자가 고를 수 있는 하한. 이보다 짧으면 정상 앱에서도 조기 실패가 잦아진다.
    static let minResolve: Float = 0.25

    /// 해석 단계에서 **대상 앱의 응답을 기다리는** AX 왕복 횟수(표준 창 기준):
    /// focusedWindow · AXFullScreen · minimized · subrole · position · size = 6.
    /// 비표준 subrole이면 `isMovableAndResizable`의 settable 2회가 더 붙어 8이 된다
    /// (근거 표: `.docs/review/ax-main-thread-blocking-audit-2026-09-09.md`의 resolve 행 "6~8").
    ///
    /// ⚠️ 호출부를 세면 `AXUIElementSetMessagingTimeout` 2회가 더 보이지만 **세지 않는다.**
    /// 그 함수는 대상 앱에 메시지를 보내지 않아 `.cannotComplete`로 실패하지 않는다 — SDK가 명시한
    /// 실패는 잘못된 양수 인자와 무효 element뿐이다. 즉 타임아웃에 묶이는 호출이 아니다.
    /// 이 문단이 없으면 호출부를 다시 센 누군가가 8로 "고쳐" 아래 불변식을 깬다.
    ///
    /// 이 예산이 실제로 걸리는 대상은 **8회 경로(비표준 subrole)** 다. 표준 6회 경로에서는 사실상 걸리지
    /// 않는다 — 예산 검사까지 온 읽기는 전부 타임아웃 전에 답했다는 뜻이라 각각 `timeout` 미만이고,
    /// 따라서 합도 `6 × timeout`(= 예산) 미만이기 때문이다(AX 사이의 계산 시간은 무시할 수준).
    /// 즉 이 가드는 "표준 창이 조금 느릴 때"가 아니라 "읽기가 2회 더 붙는 창이 느릴 때"를 위한 것이다.
    ///
    /// 8로 잡으면 그 8회 경로마저 구조적 최대치와 같아져 예산 검사가 **어느 경로에서도** 안 걸리는
    /// 죽은 코드가 된다. 그래서 6이다.
    ///
    /// **개수이므로 `Int`다.** `Float`이면 "5.5회 AX 호출" 같은 무의미한 값이 조용히 컴파일된다 —
    /// 이 파일이 `clampedResolve`로 막으려는 바로 그 종류의 실수다.
    static let resolveReadCount: Int = 6

    /// 이전 하드코딩 예산(초). 바닥값으로 남겨 둔다 — 아래 참조.
    static let legacyResolveBudget: TimeInterval = 3

    /// 해석 단계 전체 예산(초). 개별 읽기는 `timeout`으로 묶이지만 합은 묶이지 않으므로, 합의 상한을
    /// 사용자가 고른 `timeout`에 비례시킨다. 기본값에서 6 × 0.5 = 3.0으로 **이전 하드코딩 상수와 같다.**
    ///
    /// **이전 값보다 짧아지지는 않는다(바닥 3초).** 순수 비례로 두면 Quick(0.25초)의 예산이 1.5초가 되는데,
    /// 이전에는 3초라 8회 경로의 구조적 최대치(8 × 0.25 = 2.0초)로도 **도달할 수 없었다.** 즉 Quick
    /// 사용자는 예산에 걸린 적이 없다가 갑자기 걸리게 되고, 그 실패는 이제 눈에 보이므로 —
    /// **이전에 성공하던 명령이 beep과 함께 실패한다.** 고치려는 결함은 Patient가 과소 예산이라는
    /// 것이었지 Quick이 과대 예산이라는 게 아니었다. 버그 수정이 새 실패 모드를 들이지 않게 바닥을 둔다.
    static func resolveBudget(for timeout: Float) -> TimeInterval {
        max(TimeInterval(resolveReadCount) * TimeInterval(timeout), legacyResolveBudget)
    }

    /// 재시도 판정의 경과 상한(초). **명령이 시작된 시각** 기준이다 — 해석·권한 확인·애니메이션 억제에
    /// 이미 쓴 시간이 여기 들어간다. 이전에는 쓰기 함수 진입부터 재는 평탄한 1초였는데, 그 앞구간이
    /// 느린 앱일수록 길어져 "프리즈를 키우지 않으려는" 가드가 정작 프리즈가 심할 때 통과했다.
    ///
    /// 해석 예산 + 쓰기 상한으로 잡는다. 해석이 예산을 넘으면 Executor 가 이미 명령을 실패시키므로
    /// (`.resolveBudgetExceeded`), 쓰기 단계에 남는 몫은 `write` 한 번치다. 기본값에서 3.0 + 2.0 = 5.0초.
    ///
    /// Quick 이 Balanced 와 같은 5.0 인 것은 `resolveBudget` 의 바닥(3초) 때문이다 — 그 바닥이 사라지면
    /// 3.5 가 된다. `CommandEngineTests` 가 세 값을 리터럴로 고정한다(공식으로 단정하면 항진명제다).
    static func writeRetryBudget(for timeout: Float) -> TimeInterval {
        resolveBudget(for: timeout) + TimeInterval(write)
    }

    /// 두 값의 관계가 유지되는가. 테스트가 검사하는 불변식을 코드로 표현해 둔다.
    static var invariantHolds: Bool {
        write >= resolve
    }

    /// 고급 설정에서 온 값을 안전한 범위로 접는다. 저장된 defaults는 손으로 편집될 수 있으므로
    /// 신뢰하지 않는 입력으로 다룬다.
    ///
    /// 그대로 쓰면 두 가지가 깨진다:
    ///  - `0`은 `AXUIElementSetMessagingTimeout`이 **"전역 기본값(6초)으로 복귀"** 로 해석한다.
    ///    음수는 `kAXErrorIllegalArgument`다. 둘 다 이 설계가 막으려는 것이다.
    ///  - `write`를 넘으면 쓰기 단계의 상향이 상한을 *내리는* 동작이 되어, 조용한 스킵을 피하려던
    ///    목적이 정확히 뒤집힌다.
    ///
    /// NaN·무한은 유한하지 않으므로 기본값으로 되돌린다(`min`/`max`는 NaN을 걸러주지 않는다).
    static func clampedResolve(_ requested: Float) -> Float {
        guard requested.isFinite, requested > 0 else { return resolve }
        return min(max(requested, minResolve), write)
    }
}

/// 고급 설정이 노출하는 해석 상한 선택지. 값과 표시 문구를 한곳에 묶어 인덱스로 짝을 맞추다
/// 어긋나는 일이 없게 한다(`Commands/WindowCommand`의 displayName과 같은 패턴).
///
/// 숫자는 동종 윈도우 매니저 실측에서 가져왔다 — 0.25초는 alt-tab-macos가 **같은 포커스 창
/// 읽기에** 쓰는 값이고, 1초는 그 프로세스 전역 상한이다.
nonisolated enum ResolveTimeoutChoice: String, CaseIterable {
    case quick
    case balanced
    case patient

    static let `default` = ResolveTimeoutChoice.balanced

    var seconds: Float {
        switch self {
        case .quick:
            AXMessagingTimeout.minResolve
        case .balanced:
            AXMessagingTimeout.resolve
        case .patient:
            1.0
        }
    }

    /// 설정창 팝업에 그대로 노출된다 — 나머지 UI와 같이 영어로 유지(현지화는 추후 일괄).
    var title: String {
        switch self {
        case .quick:
            "Quick (0.25s)"
        case .balanced:
            "Balanced (0.5s)"
        case .patient:
            "Patient (1s)"
        }
    }

    /// 저장된 초 값에 가장 가까운 선택지. defaults에 임의의 값이 들어 있어도 팝업이 항상 하나를
    /// 고르게 해, UI가 "선택 없음" 상태로 빠지지 않는다.
    static func nearest(toSeconds seconds: Float) -> ResolveTimeoutChoice {
        allCases.min { abs($0.seconds - seconds) < abs($1.seconds - seconds) } ?? .default
    }
}
