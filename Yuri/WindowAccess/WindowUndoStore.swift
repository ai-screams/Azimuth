import ApplicationServices

/// 창별 직전 frame을 1단계 저장한다. AXUIElement는 CFEqual/CFHash로 같은 창을 식별한다.
/// 메뉴/단축키(메인 스레드) 진입점에서만 사용. @MainActor로 격리 강제됨.
@MainActor
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

    private struct Entry {
        let frame: CGRect
        let pid: pid_t
    }

    private let capacity = 64
    private var entries: [Key: Entry] = [:]
    private var order: [Key] = []

    func record(_ frame: CGRect, pid: pid_t, for element: AXUIElement) {
        let key = Key(element: element)
        if entries[key] == nil {
            order.append(key)
            if order.count > capacity {
                let oldest = order.removeFirst()
                entries.removeValue(forKey: oldest)
            }
        }
        entries[key] = Entry(frame: frame, pid: pid)
    }

    /// pid가 일치할 때만 직전 frame을 돌려준다(닫힌 창의 element 재사용으로 인한 오인 방지).
    func previousFrame(for element: AXUIElement, pid: pid_t) -> CGRect? {
        let key = Key(element: element)
        guard let entry = entries[key], entry.pid == pid else { return nil }
        return entry.frame
    }

    func clear(for element: AXUIElement) {
        let key = Key(element: element)
        entries.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }
}
