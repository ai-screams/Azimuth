import ApplicationServices

/// 창별 직전 frame을 1단계 저장한다. AXUIElement는 CFEqual/CFHash로 같은 창을 식별한다.
/// 메뉴/단축키(메인 스레드) 진입점에서만 사용. @MainActor로 격리 강제됨.
@MainActor
final class WindowUndoStore {
    private struct Key: Hashable {
        let element: AXUIElement
        let pid: pid_t

        /// pid를 키에 포함해, 서로 다른 프로세스가 AXUIElement 포인터 재사용으로
        /// 같은 슬롯을 공유(다른 앱의 entry를 덮어씀)하는 것을 막는다.
        static func == (lhs: Key, rhs: Key) -> Bool {
            lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(pid)
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
        let key = Key(element: element, pid: pid)
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
        let key = Key(element: element, pid: pid)
        guard let entry = entries[key], entry.pid == pid else { return nil }
        return entry.frame
    }

    func clear(for element: AXUIElement, pid: pid_t) {
        let key = Key(element: element, pid: pid)
        entries.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }

    /// 저장된 모든 직전 frame을 버린다. 디스플레이 재구성 시 절대 frame이 무효화되므로 호출한다.
    func clearAll() {
        entries.removeAll()
        order.removeAll()
    }
}
