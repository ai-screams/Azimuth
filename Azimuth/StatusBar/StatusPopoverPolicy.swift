//
//  StatusPopoverPolicy.swift
//  Azimuth
//
//  메뉴바 팝오버(#178)의 판단을 값으로: 상태 아이콘 클릭이 팝오버와 메뉴 중 무엇을 여는지,
//  명령 격자에서 화살표 키가 커서를 어디로 옮기는지. 뷰와 컨트롤러는 이 결과를 실행만 한다.
//

nonisolated enum StatusClickPolicy {
    enum Action: Equatable {
        case showPopover
        case closePopover
        case showMenu
    }

    /// 왼쪽 클릭은 팝오버를 열고 닫는다. 오른쪽 클릭과 Control-클릭은 기존 메뉴를 연다
    /// (키보드 탐색이 되는 `NSMenu`와 DEBUG 항목이 남는 자리).
    static func action(isRightClick: Bool, isControlDown: Bool, popoverShown: Bool) -> Action {
        if isRightClick || isControlDown { return .showMenu }
        return popoverShown ? .closePopover : .showPopover
    }
}

/// 팝오버가 닫힐 때 활성화를 직전 앱에 돌려줄지. `NSMenu`는 앱을 활성화하지 않았으므로, 다른 앱을 쓰다가
/// 열었다면 닫은 뒤 그 앱으로 돌아가야 키 입력이 이어진다. 창을 여는 단추(설정, 업데이트)로 닫았으면 그 창이
/// 앞에 남아야 하고, 바깥 클릭으로 닫혀 이미 다른 앱이 활성이면 할 일이 없다.
/// 열려 있던 Azimuth 창(설정 등)은 기준이 아니다: 그 창이 뒤에 있어도 사용자는 다른 앱을 쓰던 중이다.
nonisolated enum PopoverActivationPolicy {
    static func shouldReturnActivation(wasActiveBeforeOpening: Bool, isActive: Bool, openedWindow: Bool) -> Bool {
        !wasActiveBeforeOpening && isActive && !openedWindow
    }
}

/// 명령 격자의 키보드 커서. 그룹마다 새 줄에서 시작하고 한 줄은 `columns`칸이다.
/// 커서는 그룹 순서대로 이어 붙인 명령 목록의 평평한 인덱스다.
nonisolated struct PopoverGridLayout: Equatable {
    enum Move: Equatable {
        case left
        case right
        case up
        case down
    }

    static let columns = 8

    /// 줄마다 평평한 인덱스 범위.
    let rows: [Range<Int>]

    init(groupSizes: [Int], columns: Int = Self.columns) {
        var rows: [Range<Int>] = []
        var start = 0
        for size in groupSizes {
            var rowStart = start
            while rowStart < start + size {
                let rowEnd = min(rowStart + columns, start + size)
                rows.append(rowStart ..< rowEnd)
                rowStart = rowEnd
            }
            start += size
        }
        self.rows = rows
    }

    var count: Int {
        rows.last?.upperBound ?? 0
    }

    /// 커서가 없으면 어느 방향이든 첫 칸. 좌우는 평평한 순서로 한 칸(줄을 넘어감), 끝에서는 멈춘다.
    /// 위아래는 이웃 줄의 같은 열, 그 줄이 짧으면 마지막 칸.
    func moved(from index: Int?, _ move: Move) -> Int? {
        guard !rows.isEmpty else { return nil }
        guard let index, let row = rows.firstIndex(where: { $0.contains(index) }) else { return 0 }
        switch move {
        case .left:
            return max(index - 1, 0)
        case .right:
            return min(index + 1, count - 1)
        case .up, .down:
            let target = move == .up ? row - 1 : row + 1
            guard rows.indices.contains(target) else { return index }
            let column = index - rows[row].lowerBound
            return min(rows[target].lowerBound + column, rows[target].upperBound - 1)
        }
    }
}

extension PopoverGridLayout {
    /// 격자 순서: 그룹 순서대로 이어 붙인 `menuCommands`. 커서 인덱스는 이 배열의 인덱스다
    /// (`menuCommands` 자체는 그룹끼리 섞여 있어 그 인덱스를 쓰면 커서가 엉뚱한 타일을 가리킨다).
    static let commands = CommandGroup.allCases.flatMap { WindowCommand.menuCommands(in: $0) }
    /// 팝오버가 쓰는 격자. 줄이 `commands`와 같은 순서로 그룹을 나눈다.
    static let standard = Self(groupSizes: CommandGroup.allCases.map { WindowCommand.menuCommands(in: $0).count })
}
