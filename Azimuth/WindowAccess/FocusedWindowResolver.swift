import ApplicationServices
import Cocoa
import os

nonisolated struct ResolvedWindow: Equatable {
    let element: AXUIElement
    /// 대상 앱 엘리먼트(창 아님). WindowFrameWriter가 쓰기 직전 AXEnhancedUserInterface 등을
    /// 끄는 데 쓴다. resolve 시 이미 생성·타임아웃을 건 것을 재사용한다(pid 재생성 금지).
    let appElement: AXUIElement
    let subrole: String
    let pid: pid_t
    let frame: WindowFrame

    /// `FocusedWindowResolver`만 만들 수 있다. 자동 생성되는 internal memberwise init을 막는 것이
    /// 목적이다 — 모듈 안 누구나 raw `AXUIElement`로 하나 만들 수 있으면 그 element에는 해석 단계의
    /// messaging timeout이 걸려 있지 않아 AX 호출이 기본 6초로 나간다.
    ///
    /// `WindowFrameWriter.apply`가 상한 상향에 실패해도 중단하지 않는 근거("element는 해석 단계가
    /// 걸어둔 짧은 상한을 유지한다")가 바로 이 불변식에 기대고 있고, `WindowAccess/AGENTS.md`는
    /// 그 6초 폴백을 금지한다. 관례가 아니라 컴파일러가 지키게 한다.
    fileprivate init(
        element: AXUIElement,
        appElement: AXUIElement,
        subrole: String,
        pid: pid_t,
        frame: WindowFrame
    ) {
        self.element = element
        self.appElement = appElement
        self.subrole = subrole
        self.pid = pid
        self.frame = frame
    }
}

@MainActor
enum FocusedWindowResolver {
    private static let supportedSubroles: Set<String> = [
        kAXStandardWindowSubrole as String,
        kAXDialogSubrole as String
    ]

    /// 비공개 속성. 풀스크린은 subrole로 구분 불가해 이 속성으로 판별한다(macOS 10.11+ 사실상 표준).
    private static let fullScreenAttribute = "AXFullScreen"

    // AX IPC는 동기라 응답 없는 앱이 메인 스레드를 막을 수 있다(기본 6초). 상한 값과 쓰기 단계와의
    // 대소 관계는 Shared/AXMessagingTimeout이 소유한다.

    /// 해석 단계 messaging timeout(초). 읽기 전용 — 쓰기는 `setResolveTimeout(_:)`만 가능하고
    /// 거기서 클램프된다. 0은 AX가 "전역 기본값(6초) 복귀"로 해석하고 음수는 illegal argument라,
    /// 원시 사용자 입력이 그대로 들어오면 이 설정이 있다는 이유로 기본 동작이 조용히 나빠진다.
    ///
    /// 이전에는 `static var`에 주석으로 "직접 대입하지 말 것"이라고만 적어 두었다. 같은 파일 위쪽
    /// `ResolvedWindow`의 fileprivate init이 세운 원칙 — **관례가 아니라 컴파일러가 지키게 한다** — 을
    /// 여기에도 적용한다. `AXMessagingTimeout.resolveBudget(for:)`이 이 값의 두 번째 소비자가 되면서
    /// 클램프 하나가 두 동작(읽기 상한·예산)을 좌우하게 됐기 때문이다.
    static var resolveTimeout: Float {
        storedResolveTimeout
    }

    /// 고급 설정에서 온 값을 클램프해 반영한다. 유일한 쓰기 경로다.
    static func setResolveTimeout(_ seconds: Float) {
        storedResolveTimeout = AXMessagingTimeout.clampedResolve(seconds)
    }

    private static var storedResolveTimeout: Float = AXMessagingTimeout.resolve

    static func resolveFocusedWindow(for app: NSRunningApplication) -> Result<ResolvedWindow, WindowResolutionError> {
        guard AccessibilityPermissionService.currentStatus().isTrusted else {
            return .failure(.permissionDenied)
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if case let .failure(error) = setMessagingTimeout(on: appElement, label: "app") {
            return .failure(error)
        }
        let (windowOrNil, windowError) = AXAttribute.element(appElement, kAXFocusedWindowAttribute as String)
        guard windowError == .success, let window = windowOrNil else {
            return .failure(mapWindowLookupError(windowError))
        }
        // 타임아웃은 element 단위라 창 element에도 건다(이후 읽기 + WindowFrameWriter의 쓰기까지 적용).
        if case let .failure(error) = setMessagingTimeout(on: window, label: "window") {
            return .failure(error)
        }

        switch inspect(window) {
        case let .failure(error):
            return .failure(error)
        case let .success(inspected):
            return .success(ResolvedWindow(
                element: window,
                appElement: appElement,
                subrole: inspected.subrole ?? (kAXUnknownSubrole as String),
                pid: app.processIdentifier,
                frame: inspected.frame
            ))
        }
    }

    /// 창 게이트(풀스크린·최소화·창 종류)와 frame 읽기를 묶어, 통과하면 subrole과 frame을 함께 돌려준다.
    private static func inspect(
        _ window: AXUIElement
    ) -> Result<(subrole: String?, frame: WindowFrame), WindowResolutionError> {
        switch gate(window) {
        case let .failure(error):
            return .failure(error)
        case let .success(subrole):
            return readFrame(window).map { (subrole, $0) }
        }
    }

    /// 지원하지 않는 창을 걸러낸다. 통과하면 subrole(속성이 없으면 nil)을 돌려준다.
    ///
    /// 짧은 `AXMessagingTimeout.resolve` 아래에서는 read 실패가 타임아웃일 확률이 올라가는데, `AXAttribute`의 얇은
    /// 래퍼는 어떤 오류든 nil로 뭉갠다. "값이 없다"와 "앱이 답하지 않았다"를 구분해야 하는 곳만
    /// 오류 동반 변형을 쓰고, 타임아웃이면 **진행하지 않고 중단**한다(fail-closed).
    private static func gate(_ window: AXUIElement) -> Result<String?, WindowResolutionError> {
        // 풀스크린은 subrole로 구분 불가 → subrole 검사보다 먼저, 비공개 "AXFullScreen" 속성으로 판별.
        let (fullScreen, fullScreenError) = AXAttribute.boolValue(window, fullScreenAttribute)
        if fullScreen == true { return .failure(.fullscreenWindow) }
        // 타임아웃을 "풀스크린 아님"으로 단정하면 풀스크린 창에 쓰기가 들어간다 → 중단한다.
        // 속성 자체가 없는 앱(.attributeUnsupported/.noValue)은 정상 진행이어야 하므로 이 코드만 걸러낸다.
        if fullScreenError == .cannotComplete {
            return .failure(.appUnresponsive(code: fullScreenError.rawValue))
        }

        // 방어적 최소화 검사 (포커스 경로에서는 보통 NoValue로 이미 걸림). 여기서는 타임아웃을 중단
        // 사유로 쓰지 않는다 — 비가시 창에 쓰기가 들어가도 무해하고, 아래 frame 읽기가 backstop이다.
        if AXAttribute.bool(window, kAXMinimizedAttribute as String) == true {
            return .failure(.noFocusedWindow)
        }

        // 표준 창/다이얼로그는 허용. 그 외(JetBrains 등 자바/AWT, 일부 Electron의 비표준·누락 subrole)는
        // 위치·크기를 실제로 설정할 수 있을 때만 허용한다(시트·팝오버 등은 settable=false라 계속 차단).
        let (subrole, subroleError) = AXAttribute.stringValue(window, kAXSubroleAttribute as String)
        // 타임아웃이면 isMovableAndResizable로 AX 호출을 2회 더 쓰지 않고 중단한다 — 느린 앱에서
        // 오히려 IPC가 늘어나는 것을 막는다.
        if subroleError == .cannotComplete {
            return .failure(.appUnresponsive(code: subroleError.rawValue))
        }
        let isSupportedSubrole = subrole.map(supportedSubroles.contains) ?? false
        guard isSupportedSubrole || isMovableAndResizable(window) else {
            return .failure(.unsupportedWindowType(subrole: subrole))
        }
        return .success(subrole)
    }

    /// 창의 현재 frame. 실패 사유를 실제 AX 오류로 보고한다 — 타임아웃을 noValue로 오표기하지 않게
    /// (기존에는 원인과 무관하게 `.axError(noValue)`였다).
    ///
    /// 읽기마다 `.cannotComplete`를 **즉시** 검사한다. 두 가지를 동시에 지킨다:
    ///  - origin이 타임아웃이면 size를 읽지 않고 중단한다. 원래 `guard let a = …, let b = …`가
    ///    갖고 있던 short-circuit이고(헬퍼로 쪼개며 잃었던 것), 응답 없는 앱에서 블로킹이 2배가
    ///    되지 않는다. 위 `gate()`가 타임아웃에 조기 중단하는 정책과도 같다.
    ///  - 타임아웃을 다른 오류가 가리지 않는다. 뒤에서 한 번에 고르면 origin이
    ///    `.attributeUnsupported`이고 size가 타임아웃일 때 앞의 것이 뽑혀 `.appUnresponsive`를 놓친다.
    private static func readFrame(_ window: AXUIElement) -> Result<WindowFrame, WindowResolutionError> {
        let (origin, originError) = AXAttribute.pointValue(window, kAXPositionAttribute as String)
        if originError == .cannotComplete { return .failure(.appUnresponsive(code: originError.rawValue)) }
        let (size, sizeError) = AXAttribute.sizeValue(window, kAXSizeAttribute as String)
        if sizeError == .cannotComplete { return .failure(.appUnresponsive(code: sizeError.rawValue)) }
        guard let origin, let size else {
            // 값이 nil인데 오류가 .success인 경우(타입 불일치·AXValueGetValue 실패)는 .noValue로 폴백 —
            // "AX는 답했으나 우리가 쓸 수 없다"는 뜻이라 기존 동작과 같다.
            let failure = [originError, sizeError].first { $0 != .success } ?? .noValue
            return .failure(.axError(code: failure.rawValue))
        }
        // NaN·무한·0·음수 frame(비정상 앱·화면 전환 순간)은 target 계산·화면 fallback을 오염시키므로 차단.
        guard FrameCalculator.isUsableFrame(CGRect(origin: origin, size: size)) else {
            return .failure(.invalidFrame)
        }
        return .success(WindowFrame(origin: origin, size: size))
    }

    static func resolveFrontmostFocusedWindow(
        tracker: FrontmostAppTracker
    ) -> Result<ResolvedWindow, WindowResolutionError> {
        guard let app = tracker.targetApplication else {
            return .failure(.noFrontmostApplication)
        }
        return resolveFocusedWindow(for: app)
    }

    /// 타임아웃 설정 실패 시 기본 6초 경로로 진행하지 않는다. SDK가 명시한 실패는 잘못된 양수 인자와
    /// 무효 element뿐이다. 값은 `AXMessagingTimeout.resolve` 상수이므로 어느 쪽이든 이후 AX 호출을
    /// 계속할 근거가 없다.
    private static func setMessagingTimeout(
        on element: AXUIElement,
        label: String
    ) -> Result<Void, WindowResolutionError> {
        let error = AXUIElementSetMessagingTimeout(element, resolveTimeout)
        guard error != .success else { return .success(()) }
        Log.windows.error("SetMessagingTimeout(\(label)) failed (\(error.rawValue)) — resolution aborted")
        return .failure(.messagingTimeoutConfigurationFailed(code: error.rawValue))
    }

    private static func mapWindowLookupError(_ error: AXError) -> WindowResolutionError {
        switch error {
        case .noValue:
            .noFocusedWindow
        case .apiDisabled:
            .permissionDenied
        case .cannotComplete, .notImplemented, .attributeUnsupported:
            .appUnresponsive(code: error.rawValue)
        default:
            .axError(code: error.rawValue)
        }
    }

    /// 위치·크기 속성을 실제로 설정할 수 있는 창인지. subrole이 비표준/누락이어도
    /// 이동·리사이즈가 가능하면 지원 대상으로 본다(JetBrains 등 자바 창 대응).
    private static func isMovableAndResizable(_ window: AXUIElement) -> Bool {
        func settable(_ attribute: String) -> Bool {
            var flag = DarwinBoolean(false)
            let err = AXUIElementIsAttributeSettable(window, attribute as CFString, &flag)
            return err == .success && flag.boolValue
        }
        return settable(kAXPositionAttribute as String) && settable(kAXSizeAttribute as String)
    }
}
