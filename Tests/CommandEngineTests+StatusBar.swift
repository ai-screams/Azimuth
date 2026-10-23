// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 메뉴바 팝오버(#178)의 클릭 분기와 격자 키보드 커서.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).

import Foundation

extension CommandEngineTests {

    // 이것을 실패시키는 것: Control-클릭을 왼쪽 클릭으로 보는 것, 오른쪽 클릭이 열린 팝오버를 닫기만 하는 것,
    // 열린 팝오버를 왼쪽 클릭이 다시 여는 것(두 번째 클릭으로 닫히지 않음).
    static func testStatusClickPolicy() {
        func action(_ right: Bool, _ control: Bool, _ shown: Bool) -> String {
            "\(StatusClickPolicy.action(isRightClick: right, isControlDown: control, popoverShown: shown))"
        }
        expectName("left click opens", action(false, false, false), "showPopover")
        expectName("left click again closes", action(false, false, true), "closePopover")
        expectName("control-click opens the menu", action(false, true, false), "showMenu")
        expectName("right click opens the menu over the popover", action(true, false, true), "showMenu")
    }

    // 이것을 실패시키는 것: 이미 Azimuth를 쓰던 중에 연 팝오버가 닫히며 다른 앱으로 넘기는 것,
    // 설정 창을 띄운 단추 뒤에 넘기는 것, 바깥 클릭으로 이미 넘어간 뒤 또 넘기는 것.
    static func testPopoverActivationPolicy() {
        func returns(_ wasActive: Bool, _ active: Bool, _ opened: Bool) -> String {
            let value = PopoverActivationPolicy.shouldReturnActivation(
                wasActiveBeforeOpening: wasActive, isActive: active, openedWindow: opened
            )
            return "\(value)"
        }
        expectName("from another app, closed with Escape", returns(false, true, false), "true")
        expectName("Azimuth was already in use", returns(true, true, false), "false")
        expectName("a button opened a window", returns(false, true, true), "false")
        expectName("an outside click already left", returns(false, false, false), "false")
    }

    // 그룹마다 새 줄, 한 줄 8칸. 크기 [4, 10, 0, 3] → 줄 0..<4, 4..<12, 12..<14, 14..<17.
    // 이것을 실패시키는 것: 그룹이 새 줄에서 시작하지 않는 것, 끝에서 멈추지 않는 것,
    // 짧은 줄로 내려갈 때 마지막 칸에 붙지 않는 것, 위아래가 첫 줄·마지막 줄 밖으로 나가는 것.
    static func testPopoverGridLayout() {
        let layout = PopoverGridLayout(groupSizes: [4, 10, 0, 3])
        expectName("rows", "\(layout.rows)", "[Range(0..<4), Range(4..<12), Range(12..<14), Range(14..<17)]")
        func moved(_ index: Int?, _ move: PopoverGridLayout.Move) -> String {
            layout.moved(from: index, move).map { "\($0)" } ?? "nil"
        }
        expectName("no cursor starts at the first tile", moved(nil, .down), "0")
        expectName("right crosses into the next row", moved(3, .right), "4")
        expectName("left stops at the start", moved(0, .left), "0")
        expectName("right stops at the end", moved(16, .right), "16")
        expectName("down keeps the column", moved(2, .down), "6")
        expectName("down into a short row clamps", moved(11, .down), "13")
        expectName("up keeps the column", moved(13, .up), "5")
        expectName("up from the first row stays", moved(1, .up), "1")
        expectName("down from the last row stays", moved(15, .down), "15")
        let empty = PopoverGridLayout(groupSizes: [])
        expectName("empty grid has no cursor", "\(empty.moved(from: nil, .right) == nil)", "true")

        // 실제 격자: 34개 전부, 줄마다 한 그룹, 8칸 이하. 커서 인덱스가 가리키는 명령 목록과 줄이 같은 순서여야 한다.
        let standard = PopoverGridLayout.standard
        let commands = PopoverGridLayout.commands
        expectName("grid holds every menu command", "\(standard.count)/\(commands.count)", "34/34")
        let mixedRows = standard.rows.filter { Set(commands[$0].map(\.group.rawValue)).count != 1 }
        expectName("each row is one group", "\(mixedRows.count)", "0")
        let wideRows = standard.rows.filter { $0.count > PopoverGridLayout.columns }
        expectName("rows fit the columns", "\(wideRows.count)", "0")
    }
}
