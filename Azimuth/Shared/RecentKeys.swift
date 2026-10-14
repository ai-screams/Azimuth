//
//  RecentKeys.swift
//  Azimuth
//
//  최근 사용 순서(LRU)와 상한 초과 시 퇴출할 키 — 창별 저장소가 무엇을 버릴지 정한다(#170).
//
//  왜 따로 있나: `WindowUndoStore`의 키는 `AXUIElement`를 들고 있어 하네스에서 만들 수 없다. 순서와 퇴출 규칙은
//  키의 정체와 무관하므로 제네릭 값으로 빼서 `make test`가 정수 키로 검증한다. 순수 로직 — scripts/harness-sources.sh에 있다.
//

nonisolated struct RecentKeys<Key: Hashable> {
    /// 오래 안 쓴 것 → 최근 쓴 것.
    private(set) var keys: [Key] = []

    /// 키를 가장 최근으로 올린다. 이미 있으면 자리를 옮긴다 — 자주 쓰는 오래된 창이 삽입 순서로 먼저 밀려나지 않게.
    mutating func touch(_ key: Key) {
        keys.removeAll { $0 == key }
        keys.append(key)
    }

    mutating func remove(_ key: Key) {
        keys.removeAll { $0 == key }
    }

    mutating func removeAll() {
        keys.removeAll()
    }

    /// 상한을 넘는 만큼 가장 오래 안 쓴 키부터 빼서 돌려준다(오래된 것부터). 호출부는 그 키의 값을 지운다.
    /// 상한을 줄였을 때 한 번에 여러 개가 나갈 수 있다.
    mutating func evict(over capacity: Int) -> [Key] {
        let excess = keys.count - Swift.max(capacity, 0)
        guard excess > 0 else { return [] }
        let evicted = Array(keys.prefix(excess))
        keys.removeFirst(excess)
        return evicted
    }
}
