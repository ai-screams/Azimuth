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

    /// 두 값의 관계가 유지되는가. 테스트가 검사하는 불변식을 코드로 표현해 둔다.
    static var invariantHolds: Bool {
        write >= resolve
    }
}
