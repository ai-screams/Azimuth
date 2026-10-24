// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 명령 팔레트(#183)의 검색 순서, 선택, 최근 목록, 미리 보기 frame,
// 팔레트 단축키. 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).

import Carbon.HIToolbox
import Foundation

extension CommandEngineTests {

    private static func names(_ query: String, recent: [String] = []) -> String {
        CommandPaletteSearch.results(query: query, recent: recent).map(\.displayName).joined(separator: ",")
    }

    // 이것을 실패시키는 것: 이름 시작(순위 0)을 이름 낱말(순위 1)과 같은 순위로 두는 것, 별칭·그룹 이름을 빼는 것,
    // 낱말 하나만 맞아도 걸리게 하는 것, "two thirds"를 낱말 둘로 나누는 것, 최근을 순위보다 앞에 두는 것.
    static func testCommandPaletteSearch() {
        expectName("left: name start, then name words", names("left"),
                   "Left 1/2,Left 1/3,Left 2/3,Move Left,Shrink Left 1/2,Shrink Left 2/3,Move to Left Display")
        expectName("third: alias and group, no 2/3", names("third"),
                   "Left 1/3,Center 1/3,Right 1/3,Top 1/3,Middle 1/3,Bottom 1/3")
        expectName("two thirds: one alias", names("two thirds"),
                   "Left 2/3,Right 2/3,Top 2/3,Bottom 2/3,Shrink Left 2/3,Shrink Right 2/3,Shrink Top 2/3,Shrink Bottom 2/3")
        expectName("top display: up and top are one word", names("top display"), "Move to Up Display")
        expectName("every word must match", names("le hal"), "Left 1/2,Shrink Left 1/2")
        expectName("max: core group name is not searched", names("max"), "Maximize,Maximize with Gaps")
        expectName("halves group name", names("halves"), "Left 1/2,Right 1/2,Top 1/2,Bottom 1/2,Shrink Left 1/2,Shrink Right 1/2,Shrink Top 1/2,Shrink Bottom 1/2")
        expectName("back is undo", names("back"), "Undo")
        expectName("no match", names("zzz"), "")
        expectName("case and spaces", names("  LEFT 1/2 "), "Left 1/2,Shrink Left 1/2")

        let empty = CommandPaletteSearch.results(query: "", recent: ["undo", "maximize"])
        expectName("empty query: recent first, then menu order",
                   empty.prefix(3).map(\.identifier).joined(separator: ","), "undo,maximize,maximizeGaps")
        expectName("empty query lists every command", "\(empty.count)", "\(WindowCommand.menuCommands.count)")
        expectName("recent breaks ties within a rank", names("left", recent: ["absolute.horizontal.twoThird.first"]),
                   "Left 2/3,Left 1/2,Left 1/3,Move Left,Shrink Left 1/2,Shrink Left 2/3,Move to Left Display")
        expectName("recent does not jump ranks", names("left", recent: ["relativeHalf.left"]),
                   "Left 1/2,Left 1/3,Left 2/3,Shrink Left 1/2,Move Left,Shrink Left 2/3,Move to Left Display")
    }

    // 이것을 실패시키는 것: 끝에서 감싸 도는 것, 빈 목록에서 음수, 최근 목록 중복·상한 초과.
    static func testCommandPaletteSelectionAndRecents() {
        expectName("up at the top stays", "\(CommandPaletteSelection.moved(0, by: -1, count: 5))", "0")
        expectName("down at the bottom stays", "\(CommandPaletteSelection.moved(4, by: 1, count: 5))", "4")
        expectName("down moves", "\(CommandPaletteSelection.moved(2, by: 1, count: 5))", "3")
        expectName("empty list", "\(CommandPaletteSelection.moved(0, by: 1, count: 0))", "0")

        expectName("touch moves to front", CommandPaletteRecents.touched("a", in: ["b", "a", "c"]).joined(), "abc")
        expectName("touch caps at five",
                   CommandPaletteRecents.touched("f", in: ["a", "b", "c", "d", "e"]).joined(), "fabcd")
    }

    // 이것을 실패시키는 것: Undo·디스플레이 이동에 윤곽을 그리는 것, 던지기에 인접 화면을 넘기지 않는 것,
    // 크기 고정 창에 원래 크기 윤곽을 그리는 것, 던지기 목표의 모서리를 원래 화면 기준으로 맞추는 것.
    static func testCommandPalettePreview() {
        let area = CGRect(x: 0, y: 25, width: 1920, height: 1055)
        let leftScreen = CGRect(x: -1920, y: 25, width: 1920, height: 1055)
        let window = CGRect(x: 100, y: 100, width: 800, height: 600)
        func context(
            _ current: CGRect, recorded: SnapRecord? = nil, size: SettableAnswer = .settable
        ) -> CommandPalettePreviewContext {
            CommandPalettePreviewContext(
                current: current, workArea: area, recorded: recorded, adjacent: [.left: leftScreen], sizeSettable: size
            )
        }
        func show(_ rect: CGRect?) -> String {
            rect.map { "\($0.minX),\($0.minY),\($0.width),\($0.height)" } ?? "nil"
        }

        expectName("left half", show(CommandPalettePreview.target(for: .snapThrow(.left), in: context(window))),
                   "0.0,25.0,960.0,1055.0")
        expectName("undo has no outline", show(CommandPalettePreview.target(for: .undo, in: context(window))), "nil")
        expectName("display move has no outline",
                   show(CommandPalettePreview.target(for: .moveToDisplay(.left), in: context(window))), "nil")

        let leftHalf = CGRect(x: 0, y: 25, width: 960, height: 1055)
        let snapped = context(leftHalf, recorded: SnapRecord(edge: .left, frame: leftHalf))
        expectName("snapped left throws to the left screen",
                   show(CommandPalettePreview.target(for: .snapThrow(.left), in: snapped)),
                   "-960.0,25.0,960.0,1055.0")

        let fixed = context(window, size: .notSettable)
        expectName("fixed-size maximize keeps the size, centered",
                   show(CommandPalettePreview.target(for: .maximize, in: fixed)), "560.0,252.5,800.0,600.0")
        expectName("fixed-size left half keeps the size, at the left edge",
                   show(CommandPalettePreview.target(for: .snapThrow(.left), in: fixed)), "0.0,252.5,800.0,600.0")
        expectName("unknown size answer fails like the writer",
                   show(CommandPalettePreview.target(for: .maximize, in: context(window, size: .unknown))), "nil")

        let fixedSnapped = CGRect(x: 0, y: 25, width: 800, height: 600)
        let thrown = context(fixedSnapped, recorded: SnapRecord(edge: .left, frame: fixedSnapped), size: .notSettable)
        expectName("fixed-size throw lines up with the left screen's edge",
                   show(CommandPalettePreview.target(for: .snapThrow(.left), in: thrown)), "-800.0,252.5,800.0,600.0")
    }

    // 이것을 실패시키는 것: 명령 식별자와 같은 팔레트 식별자, ⌃⌥P가 아닌 기본값, 프리셋과 겹치는 기본값,
    // 같은 조합을 쓰는 명령을 놓치는 것.
    static func testCommandPaletteShortcut() {
        let identifiers = Set(WindowCommand.menuCommands.map(\.identifier))
        expectName("identifier is not a command",
                   "\(identifiers.contains(CommandPaletteShortcut.identifier))", "false")
        expectName("default is ⌃⌥P", CommandPaletteShortcut.standard.displayString, "⌃⌥P")
        for preset in HotkeyPreset.allCases {
            expectName("\(preset) does not use ⌃⌥P",
                       "\(CommandPaletteShortcut.conflicts(CommandPaletteShortcut.standard, in: preset.bindings))", "[]")
        }
        let custom = BindingResolver.resolve(
            preset: .standard, overrides: ["maximize": CommandPaletteShortcut.standard]
        )
        expectName("a command on ⌃⌥P conflicts",
                   "\(CommandPaletteShortcut.conflicts(CommandPaletteShortcut.standard, in: custom))", "[\"maximize\"]")
    }

    // 이것을 실패시키는 것: 팔레트를 꺼진 채 시작하는 것, 기본 조합을 사용자 지정으로 저장하는 것, 읽을 수 없는 값을
    // 그대로 쓰는 것, 최근 목록 상한을 지키지 않는 것.
    @MainActor
    static func testCommandPalettePreferences() {
        withTestDefaults { defaults in
            let store = PreferencesStore(defaults: defaults)
            expectName("palette starts on", "\(store.commandPaletteEnabled)", "true")
            store.commandPaletteEnabled = false
            expectName("palette off persists", "\(PreferencesStore(defaults: defaults).commandPaletteEnabled)", "false")

            expectName("shortcut defaults to ⌃⌥P", store.commandPaletteShortcut.displayString, "⌃⌥P")
            expectName("default is not custom", "\(store.hasCustomCommandPaletteShortcut)", "false")
            let custom = HotkeyShortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey))
            store.commandPaletteShortcut = custom
            expectName("custom persists", PreferencesStore(defaults: defaults).commandPaletteShortcut.displayString, "⌃⌥K")
            expectName("custom is marked", "\(store.hasCustomCommandPaletteShortcut)", "true")
            store.commandPaletteShortcut = CommandPaletteShortcut.standard
            expectName("setting the default clears custom", "\(store.hasCustomCommandPaletteShortcut)", "false")
            defaults.set(Data("junk".utf8), forKey: "commandPaletteShortcut")
            expectName("unreadable value reads as default", store.commandPaletteShortcut.displayString, "⌃⌥P")

            store.commandPaletteRecent = ["a", "b", "c", "d", "e", "f"]
            expectName("recent capped at five", store.commandPaletteRecent.joined(), "abcde")
        }
    }
}
