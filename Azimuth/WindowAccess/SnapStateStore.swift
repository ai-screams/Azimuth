import ApplicationServices

/// 창별로 "Azimuth가 그 창을 어느 edge로 스냅했고 그때 실제 frame이 무엇이었는지"를 기록한다.
/// snapThrow가 "이미 스냅됨 → 던지기"를 판정할 때, 느슨한 기하 추론 대신 이 상태를 참조해
/// 제약 앱(정확한 반쪽에 못 미치는)도 두 번째 입력에 던질 수 있게 하면서, 수동으로 배치한 창을
/// 첫 입력에 오판(던지기)하지 않는다(감사 H-2). 외부에서 창이 움직이면(현재 frame≠기록 frame)
/// 판정 단계에서 무효화되고, 디스플레이 재구성 시 절대 frame이 무의미해지므로 전부 버린다.
///
/// `WindowUndoStore`와 동일한 키 설계(AXUIElement는 CFEqual/CFHash로 식별, pid 포함)와 LRU 퇴출을 쓴다.
/// 메뉴/단축키(메인 스레드) 진입점에서만 사용. @MainActor로 격리 강제됨.
@MainActor
final class SnapStateStore {
    private struct Key: Hashable {
        let element: AXUIElement
        let pid: pid_t

        /// pid를 키에 포함해, 서로 다른 프로세스가 AXUIElement 포인터 재사용으로 같은 슬롯을
        /// 공유(다른 앱의 기록을 덮어씀)하는 것을 막는다.
        static func == (lhs: Key, rhs: Key) -> Bool {
            lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(pid)
            hasher.combine(CFHash(element))
        }
    }

    private let capacity = 64
    private var records: [Key: SnapRecord] = [:]
    private var order: [Key] = []

    func record(edge: SnapEdge, frame: CGRect, pid: pid_t, for element: AXUIElement) {
        let key = Key(element: element, pid: pid)
        // 재기록도 최근 사용으로 승격(LRU): 기존 위치를 빼고 끝으로 다시 넣는다.
        order.removeAll { $0 == key }
        order.append(key)
        records[key] = SnapRecord(edge: edge, frame: frame)
        if order.count > capacity {
            let oldest = order.removeFirst()
            records.removeValue(forKey: oldest)
        }
    }

    func state(for element: AXUIElement, pid: pid_t) -> SnapRecord? {
        records[Key(element: element, pid: pid)]
    }

    func clear(for element: AXUIElement, pid: pid_t) {
        let key = Key(element: element, pid: pid)
        records.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }

    /// 기록한 모든 스냅 상태를 버린다. 디스플레이 재구성 시 절대 frame이 무효화되므로 호출한다.
    func clearAll() {
        records.removeAll()
        order.removeAll()
    }
}
