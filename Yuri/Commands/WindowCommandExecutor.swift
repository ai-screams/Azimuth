import Cocoa

enum WindowCommandExecutor {
    static func run(
        _ command: WindowCommand,
        on app: NSRunningApplication,
        undoStore: WindowUndoStore
    ) -> Result<CGRect, WindowCommandError> {
        let resolved: ResolvedWindow
        switch FocusedWindowResolver.resolveFocusedWindow(for: app) {
        case let .success(window):
            resolved = window
        case let .failure(error):
            return .failure(.resolution(error))
        }

        if command == .undo {
            guard let previous = undoStore.previousFrame(for: resolved.element) else {
                return .failure(.noUndoState)
            }
            return WindowFrameWriter.apply(previous, to: resolved.element)
        }

        guard let workArea = WorkAreaResolver.workArea(forAXWindowFrame: resolved.frame.rect) else {
            return .failure(.workAreaUnavailable)
        }

        // 일반 명령은 적용 직전 현재 frame을 1단계 저장(되돌리기용).
        undoStore.record(resolved.frame.rect, for: resolved.element)
        let target = FrameCalculator.targetFrame(
            for: command,
            current: resolved.frame.rect,
            workArea: workArea
        )
        return WindowFrameWriter.apply(target, to: resolved.element)
    }

    static func run(
        _ command: WindowCommand,
        tracker: FrontmostAppTracker,
        undoStore: WindowUndoStore
    ) -> Result<CGRect, WindowCommandError> {
        guard let app = tracker.targetApplication else {
            return .failure(.resolution(.noFrontmostApplication))
        }
        return run(command, on: app, undoStore: undoStore)
    }
}
