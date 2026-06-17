import AppKit

/// AX(좌상단 원점, Y 아래로)와 Cocoa(좌하단 원점, Y 위로) 사각형을 변환한다.
/// 변환은 involution(같은 공식)이며 주 디스플레이 높이를 기준으로 Y를 뒤집는다.
enum CoordinateSpace {
    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func flip(_ rect: CGRect) -> CGRect {
        let height = primaryHeight
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
}
