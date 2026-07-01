import AppKit

/// AX(좌상단 원점, Y 아래로)와 Cocoa(좌하단 원점, Y 위로) 사각형을 변환한다.
/// 변환은 involution(같은 공식)이며 주 디스플레이 높이를 기준으로 Y를 뒤집는다.
@MainActor
enum CoordinateSpace {
    private static var primaryHeight: CGFloat {
        // 전역 좌표 원점(0,0)을 소유하는 디스플레이의 높이를 기준으로 뒤집는다.
        // NSScreen.screens.first가 항상 주 디스플레이라는 보장은 없다(멀티모니터).
        let originScreen = NSScreen.screens.first { $0.frame.origin == .zero }
        return (originScreen ?? NSScreen.screens.first)?.frame.height ?? 0
    }

    static func flip(_ rect: CGRect) -> CGRect {
        let height = primaryHeight
        // 화면 목록이 비는 순간(도킹/언도킹·전체 절전 등)엔 기준 높이가 0이 된다.
        // 그대로 뒤집으면 음수 Y의 쓰레기 frame이 나와 창이 화면 밖으로 갈 수 있으므로,
        // 변환 불가로 보고 입력을 그대로 돌려준다(상위 resolver가 화면 없음→nil로 명령을 중단).
        guard height > 0 else { return rect }
        return CGRect(
            x: rect.origin.x,
            y: height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    static func cocoaToAX(_ rect: CGRect) -> CGRect {
        flip(rect)
    }

    static func axToCocoa(_ rect: CGRect) -> CGRect {
        flip(rect)
    }

    /// 화면의 작업영역(visibleFrame)을 AX 좌표로 변환한다. 디스플레이 재구성 순간 visibleFrame이
    /// 0크기로 읽힐 수 있어, 0크기면 nil을 반환한다(0크기 작업영역이 halfRect/maximize로 흘러가
    /// 0크기 프레임 쓰기를 유발하는 것을 막는다). WorkAreaResolver·DisplayResolver 공용.
    static func axWorkArea(of screen: NSScreen) -> CGRect? {
        let visible = screen.visibleFrame
        guard visible.width > 0, visible.height > 0 else { return nil }
        return cocoaToAX(visible)
    }
}
