//
//  AXMessagingTimeout.swift
//  Azimuth
//
//  AX messaging timeout 정책. **값과 그 사이의 불변식**을 한곳에 모은다.
//  적용(누가 언제 거는가)은 나뉜 채로 둔다 — timeout은 element 단위라 해석 진입에서 한 번,
//  쓰기 진입에서 한 번 거는 것이 자연스럽다. 합쳐야 하는 것은 메커니즘이 아니라 값이다.
//
//  ⚠️ 순수 상수 파일 — AppKit/AX를 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//  두 값의 대소 관계가 설계의 전제라서, 떨어져 있으면 한쪽만 바꿔도 컴파일이 통과해 버린다.
//  그래서 하네스에 넣고 `make test`가 불변식을 검사하게 했다.
//

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
