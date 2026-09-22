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

    private let capacity = 64
    /// 값은 직전 frame 하나다. "어느 프로세스의 창인가"는 `Key`가 pid 로 이미 가른다(`SnapStateStore`와 같은 모양).
    private var entries: [Key: CGRect] = [:]
    private var order: [Key] = []

    func record(_ frame: CGRect, pid: pid_t, for element: AXUIElement) {
        let key = Key(element: element, pid: pid)
        // 재기록도 "최근 사용"으로 승격한다(진짜 LRU): 기존 위치를 빼고 끝으로 다시 넣어야
        // 자주 쓰는 오래된 창이 삽입 순서(FIFO)로 먼저 퇴출되지 않는다.
        order.removeAll { $0 == key }
        order.append(key)
        entries[key] = frame
        if order.count > capacity {
            let oldest = order.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }

    /// 닫힌 창의 element 가 다른 프로세스에서 재사용돼도 오인하지 않는다 — `Key`가 pid 를 포함하므로
    /// 다른 pid 의 조회는 애초에 다른 키다.
    func previousFrame(for element: AXUIElement, pid: pid_t) -> CGRect? {
        entries[Key(element: element, pid: pid)]
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
