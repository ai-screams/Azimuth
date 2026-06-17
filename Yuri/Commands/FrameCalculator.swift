import CoreGraphics

enum FrameCalculator {
    static func targetFrame(for command: WindowCommand, current: CGRect, workArea: CGRect) -> CGRect {
        switch command {
        case .maximize:
            workArea
        case .leftHalf:
            CGRect(
                x: workArea.minX,
                y: current.minY,
                width: workArea.width / 2,
                height: current.height
            )
        case .topHalf:
            CGRect(
                x: current.minX,
                y: workArea.minY,
                width: current.width,
                height: workArea.height / 2
            )
        }
    }
}
