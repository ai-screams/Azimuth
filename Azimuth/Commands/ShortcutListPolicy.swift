//
//  ShortcutListPolicy.swift
//  Azimuth
//
//  단축키 목록의 그룹 표시 판정. 검색어와 사용자가 펼친 그룹을 받아 그룹별로
//  "헤더를 보일지 / 펼칠지 / 구분선을 보일지"를 결정한다.
//
//  뷰에서 분리한 이유: 검색과 접힘이 상호작용하는 지점이라 틀리면 "검색했는데 결과가
//  접혀서 안 보인다"가 되는데, AppKit 뷰 계층은 테스트 하네스에서 돌릴 수 없다.
//
//  ⚠️ 순수 로직 파일 — AppKit/AX를 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//  trimmingCharacters(in:)와 CharacterSet은 Foundation이므로 그것만 import한다.
//

import Foundation

nonisolated struct ShortcutGroupDisplay: Equatable {
    /// 그룹 헤더(체크박스 + 삼각형) 자체를 보일지.
    let isHeaderVisible: Bool
    /// 하위 명령 행을 보일지. 검색 중에는 사용자의 펼침 상태와 무관하게 자동으로 펼친다.
    let isExpanded: Bool
    /// 이 그룹 **위에** 구분선을 둘지. 첫 보이는 그룹 위에는 두지 않는다.
    let isSeparatorVisible: Bool
}

nonisolated enum ShortcutListPolicy {
    /// 검색어가 명령명 또는 그룹명에 걸리는가. 공백만 있는 질의는 "검색 안 함"으로 본다.
    static func matches(query: String, command: WindowCommand) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        if command.displayName.lowercased().contains(needle) { return true }
        return command.group.displayName.lowercased().contains(needle)
    }

    /// 그룹별 표시 판정.
    ///
    /// - `matchedCounts`: 그룹별로 현재 질의에 걸린 행 수(검색 안 할 땐 전체 행 수).
    /// - `isSearching`: 질의가 비어 있지 않은가. 검색 중에는 **매칭된 그룹을 자동으로 펼친다** —
    ///   안 그러면 검색 결과가 접힌 채 숨어 검색이 무의미해진다.
    /// - `expanded`: 사용자가 삼각형으로 펼친 그룹(검색 중이 아닐 때만 쓰인다).
    static func display(
        matchedCounts: [CommandGroup: Int],
        isSearching: Bool,
        expanded: Set<CommandGroup>
    ) -> [CommandGroup: ShortcutGroupDisplay] {
        var result: [CommandGroup: ShortcutGroupDisplay] = [:]
        var seenVisible = false
        for group in CommandGroup.allCases {
            let matched = matchedCounts[group] ?? 0
            let headerVisible = matched > 0
            let isExpanded = headerVisible && (isSearching || expanded.contains(group))
            result[group] = ShortcutGroupDisplay(
                isHeaderVisible: headerVisible,
                isExpanded: isExpanded,
                isSeparatorVisible: headerVisible && seenVisible
            )
            if headerVisible { seenVisible = true }
        }
        return result
    }
}
