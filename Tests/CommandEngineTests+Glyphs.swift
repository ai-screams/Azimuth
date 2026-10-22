// Azimuth 명령 엔진(순수 로직) 회귀 테스트 — 명령 그림(#181)과 키캡 라벨.
// 공유 상태와 expect* 헬퍼는 CommandEngineTests.swift에 있다(같은 모듈로 컴파일).

import CoreGraphics
import Foundation

extension CommandEngineTests {

    // 34개 메뉴 명령 전부: 그릴 것이 있고, 상자 안에 있고, 서로 겹치는 그림이 없다.
    static func testCommandGlyphCatalog() {
        let box = CGRect(origin: .zero, size: CommandGlyph.box)
        let glyphs = WindowCommand.menuCommands.map { ($0.displayName, $0.glyph) }
        for (name, glyph) in glyphs {
            let marked = glyph.region != nil || !glyph.strokes.isEmpty || !glyph.arcs.isEmpty
            expectName("\(name) has a mark", "\(marked)", "true")
            let shapes = [glyph.screen, glyph.secondScreen, glyph.region, glyph.ghost].compactMap { $0 }
                + glyph.arcs.map(\.bounds)
            let points = glyph.strokes.flatMap { $0 }
            let inside = shapes.allSatisfy { box.contains($0) } && points.allSatisfy { box.contains($0) }
            expectName("\(name) inside the box", "\(inside)", "true")
        }
        // 이것을 실패시키는 것: 두 명령이 같은 도형을 돌려주는 것(예: Right 1/2에 Left 1/2 영역을 복사).
        var duplicates: [String] = []
        for (index, (name, glyph)) in glyphs.enumerated() {
            for (other, otherGlyph) in glyphs[(index + 1)...] where glyph == otherGlyph {
                duplicates.append("\(name) = \(other)")
            }
        }
        expectName("no two commands share a glyph", duplicates.joined(separator: ", "), "")
    }

    // 영역이 명령의 기하와 맞는지 대표 값으로 고정한다(안쪽 22×14, 원점 (3,3)).
    static func testCommandGlyphRegions() {
        let leftHalf = WindowCommand.snapThrow(.left).glyph.region ?? .null
        expect("left 1/2 region", leftHalf, CGRect(x: 3, y: 3, width: 11, height: 14))
        let centerThird = absolute(.horizontal, .third, .center).glyph.region ?? .null
        expect("center 1/3 region", centerThird, CGRect(x: 3 + 22.0 / 3, y: 3, width: 22.0 / 3, height: 14))
        let bottomTwoThirds = absolute(.vertical, .twoThird, .last).glyph.region ?? .null
        expect("bottom 2/3 region", bottomTwoThirds, CGRect(x: 3, y: 3 + 14.0 / 3, width: 22, height: 14 * 2.0 / 3))
        let shrink = WindowCommand.relativeTwoThird(.right).glyph
        expect("shrink right 2/3 ghost is the full inner area", shrink.ghost ?? .null, CommandGlyph.unit(0, 0, 1, 1))
        let shrinkRegion = shrink.region ?? .null
        expect("shrink right 2/3 region", shrinkRegion, CGRect(x: 3 + 22.0 / 3, y: 3, width: 22 * 2.0 / 3, height: 14))
        expectName("plain halves have no ghost", "\(WindowCommand.snapThrow(.left).glyph.ghost == nil)", "true")
    }

    // 화살표는 명령 방향을 가리키고, Undo는 원호 하나와 직선 세 획이다.
    static func testCommandGlyphArrows() {
        let moveLeft = WindowCommand.move(.left).glyph.strokes
        expectPoint("move left arrow head", moveLeft.first?.last ?? .zero, CGPoint(x: 17, y: 10))
        expectName("move left: body and head strokes", "\(moveLeft.count)", "2")
        let moveDown = WindowCommand.move(.down).glyph.strokes
        let downBody = moveDown.first ?? []
        expectName("move down points down", "\((downBody.last?.y ?? 0) > (downBody.first?.y ?? 0))", "true")
        let undo = WindowCommand.undo.glyph
        expectName("undo: one arc and three line strokes", "\(undo.arcs.count)/\(undo.strokes.count)", "1/3")
        expectName("undo: no region", "\(undo.region == nil)", "true")
    }

    // 디스플레이 이동: 목적지 화면을 그 방향에 따로 두고, 목표 영역은 목적지 화면 안에 둔다.
    static func testCommandGlyphDisplays() {
        for (edge, label) in [(SnapEdge.left, "left"), (.right, "right"), (.top, "top"), (.bottom, "bottom")] {
            let glyph = WindowCommand.moveToDisplay(edge).glyph
            // nil을 CGRect.null로 바꿔 비교하면 null의 좌표가 무한대라 right·bottom 비교와 contains가 늘 참이 된다.
            // 이것을 실패시키는 것: 디스플레이 그림에서 secondScreen 또는 region을 지우는 것.
            guard let second = glyph.secondScreen, let region = glyph.region else {
                expectName("display \(label): has target screen and region", "missing", "present")
                continue
            }
            let towardEdge = switch edge {
            case .left:
                second.maxX <= glyph.screen.minX
            case .right:
                second.minX >= glyph.screen.maxX
            case .top:
                second.maxY <= glyph.screen.minY
            case .bottom:
                second.minY >= glyph.screen.maxY
            }
            expectName("display \(label): target screen on that side, apart", "\(towardEdge)", "true")
            expectName("display \(label): region on the target screen", "\(second.contains(region))", "true")
        }
    }

    // 그룹별 메뉴 명령: 그룹을 이어 붙이면 menuCommands의 명령이 빠짐없이 한 번씩 나온다.
    static func testMenuCommandsByGroup() {
        let joined = CommandGroup.allCases.flatMap { WindowCommand.menuCommands(in: $0) }.map(\.identifier)
        let all = WindowCommand.menuCommands.map(\.identifier)
        expectName("groups cover every menu command once", "\(joined.sorted() == all.sorted())", "true")
        let halves = WindowCommand.menuCommands(in: .halves).map(\.identifier).joined(separator: ",")
        expectName("halves keep menu order", halves, all.filter { $0.contains("snapThrow") }.joined(separator: ","))
    }

    // 바인딩 → 단축키 값: 키코드와 수정자를 그대로 옮긴다.
    static func testBindingShortcut() {
        let binding = HotkeyPreset.standard.bindings.first { $0.command == .maximize }
        expectName("maximize binding shortcut", binding?.shortcut.displayString ?? "nil", "⌃⌥↩")
    }

    // 키캡 라벨: 수정자 하나씩 + 키 하나. 여러 글자 키도 캡 하나.
    static func testKeycapLabels() {
        let mods = UInt32(0x1000 | 0x0800) // controlKey | optionKey
        let arrow = HotkeyShortcut(keyCode: 0x7B, modifiers: mods)
        expectName("⌃⌥← caps", arrow.keycapLabels.joined(separator: "|"), "⌃|⌥|←")
        // 이것을 실패시키는 것: displayString을 글자 단위로 쪼개는 구현("F","1","2").
        let function = HotkeyShortcut(keyCode: 0x6F, modifiers: mods)
        expectName("⌃⌥F12 caps", function.keycapLabels.joined(separator: "|"), "⌃|⌥|F12")
        let space = HotkeyShortcut(keyCode: 0x31, modifiers: 0)
        expectName("bare Space caps", space.keycapLabels.joined(separator: "|"), "Space")
        let all = HotkeyShortcut(keyCode: 0x00, modifiers: UInt32(0x1000 | 0x0800 | 0x0200 | 0x0100))
        expectName("⌃⌥⇧⌘A caps in order", all.keycapLabels.joined(separator: "|"), "⌃|⌥|⇧|⌘|A")
    }
}
