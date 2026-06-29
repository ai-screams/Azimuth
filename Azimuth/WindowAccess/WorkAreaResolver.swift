import AppKit

@MainActor
enum WorkAreaResolver {
    static func workArea(forAXWindowFrame axFrame: CGRect) -> CGRect? {
        let cocoaWindow = CoordinateSpace.axToCocoa(axFrame)
        guard let screen = NSScreen.bestMatch(forCocoaRect: cocoaWindow) else { return nil }
        let visible = screen.visibleFrame
        // 디스플레이 재구성 순간 visibleFrame이 0크기로 읽힐 수 있다. 0크기 작업영역을 그대로
        // 넘기면 maximize 등이 0크기 프레임을 쓰게 되므로, 변환 불가로 보고 nil(명령 중단)한다.
        guard visible.width > 0, visible.height > 0 else { return nil }
        return CoordinateSpace.cocoaToAX(visible)
    }
}
