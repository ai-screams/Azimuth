import ApplicationServices

/// 창별로 최근 frame을 설정한 깊이만큼, 설정한 창 수까지 저장한다(#170). 깊이 규칙은 순수 값 `UndoHistory`가 갖고, 여기는 창마다
/// 그 값을 하나씩 든다. AXUIElement는 CFEqual/CFHash로 같은 창을 식별한다.
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

    /// 값은 그 창의 Undo 스택이다. "어느 프로세스의 창인가"는 `Key`가 pid 로 이미 가른다(`SnapStateStore`와 같은 모양).
    private var entries: [Key: UndoHistory] = [:]
    private var order = RecentKeys<Key>()
    /// 사용자가 고른 깊이와 창 수. 값이 아니라 provider로 받는 이유: 설정 화면이 이 저장소를 몰라도 되고, 읽을 때마다
    /// 자르므로 줄이면 다음 명령·Undo부터 바로 반영된다.
    private let depth: () -> Int
    private let windowCapacity: () -> Int

    init(
        depth: @escaping () -> Int = { UndoHistory.depth.defaultValue },
        windowCapacity: @escaping () -> Int = { UndoHistory.windowCapacity.defaultValue }
    ) {
        self.depth = depth
        self.windowCapacity = windowCapacity
    }

    func record(_ frame: CGRect, pid: pid_t, for element: AXUIElement) {
        let key = Key(element: element, pid: pid)
        order.touch(key)
        entries[key, default: UndoHistory()].push(frame, depth: depth())
        evictOverCapacity()
    }

    /// 닫힌 창의 element 가 다른 프로세스에서 재사용돼도 오인하지 않는다 — `Key`가 pid 를 포함하므로
    /// 다른 pid 의 조회는 애초에 다른 키다.
    func previousFrame(for element: AXUIElement, pid: pid_t) -> CGRect? {
        evictOverCapacity()
        let key = Key(element: element, pid: pid)
        entries[key]?.trim(to: depth())
        return entries[key]?.latest
    }

    /// Undo가 `previousFrame`에 도달했을 때 그 frame을 버린다. 스택이 비면 창 기록 자체를 지운다.
    func popLatest(for element: AXUIElement, pid: pid_t) {
        let key = Key(element: element, pid: pid)
        entries[key]?.popLatest()
        guard entries[key]?.isEmpty == true else { return }
        entries.removeValue(forKey: key)
        order.remove(key)
    }

    /// 저장된 모든 Undo 기록을 버린다. 디스플레이 재구성 시 절대 frame이 무효화되므로 호출한다.
    func clearAll() {
        entries.removeAll()
        order.removeAll()
    }

    /// 창 수 상한을 넘는 만큼 가장 오래 안 쓴 창의 기록을 버린다. 설정을 줄이면 여러 개가 한 번에 나간다.
    private func evictOverCapacity() {
        for key in order.evict(over: UndoHistory.windowCapacity.clamped(windowCapacity())) {
            entries.removeValue(forKey: key)
        }
    }
}
