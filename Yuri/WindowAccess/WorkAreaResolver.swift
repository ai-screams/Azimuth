import AppKit

enum WorkAreaResolver {
    static func workArea(forAXWindowFrame axFrame: CGRect) -> CGRect? {
        let cocoaWindow = CoordinateSpace.axToCocoa(axFrame)
        guard let screen = bestScreen(for: cocoaWindow) else { return nil }
        return CoordinateSpace.cocoaToAX(screen.visibleFrame)
    }

    private static func bestScreen(for cocoaRect: CGRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let area = intersectionArea(cocoaRect, screen.frame)
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let rect = lhs.intersection(rhs)
        return rect.isNull ? 0 : rect.width * rect.height
    }
}
