import AppKit

@MainActor
enum WorkAreaResolver {
    static func workArea(forAXWindowFrame axFrame: CGRect) -> CGRect? {
        let cocoaWindow = CoordinateSpace.axToCocoa(axFrame)
        guard let screen = NSScreen.bestMatch(forCocoaRect: cocoaWindow) else { return nil }
        return CoordinateSpace.cocoaToAX(screen.visibleFrame)
    }
}
