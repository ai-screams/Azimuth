import ApplicationServices

/// 창별 직전 frame을 1단계 저장한다. AXUIElement는 CFEqual/CFHash로 같은 창을 식별한다.
final class WindowUndoStore {
    private struct Key: Hashable {
        let element: AXUIElement

        static func == (lhs: Key, rhs: Key) -> Bool {
            CFEqual(lhs.element, rhs.element)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(CFHash(element))
        }
    }

    private var frames: [Key: CGRect] = [:]

    func record(_ frame: CGRect, for element: AXUIElement) {
        frames[Key(element: element)] = frame
    }

    func previousFrame(for element: AXUIElement) -> CGRect? {
        frames[Key(element: element)]
    }
}
