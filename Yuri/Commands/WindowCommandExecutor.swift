import Cocoa

enum WindowCommandExecutor {
    static func run(_ command: WindowCommand, on app: NSRunningApplication) -> Result<CGRect, WindowCommandError> {
        let resolved: ResolvedWindow
        switch FocusedWindowResolver.resolveFocusedWindow(for: app) {
        case let .success(window):
            resolved = window
        case let .failure(error):
            return .failure(.resolution(error))
        }

        guard let workArea = WorkAreaResolver.workArea(forAXWindowFrame: resolved.frame.rect) else {
            return .failure(.workAreaUnavailable)
        }

        let target = FrameCalculator.targetFrame(
            for: command,
            current: resolved.frame.rect,
            workArea: workArea
        )
        return WindowFrameWriter.apply(target, to: resolved.element)
    }

    static func run(
        _ command: WindowCommand,
        tracker: FrontmostAppTracker
    ) -> Result<CGRect, WindowCommandError> {
        guard let app = tracker.lastFocusedApp ?? NSWorkspace.shared.frontmostApplication else {
            return .failure(.resolution(.noFrontmostApplication))
        }
        return run(command, on: app)
    }
}
