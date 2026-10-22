//
//  CommandGlyph.swift
//  Azimuth
//
//  명령 그림(#181, Outline)의 도형: 28×20 상자 좌표의 화면 윤곽·목표 영역·점선·화살표.
//  그리는 일은 UI/CommandGlyphView가 하고, 여기는 값만 정한다(하네스에서 34개 전수 검사).
//
//  ⚠️ 순수 로직 파일이다. CoreGraphics 외에 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//

import CoreGraphics

nonisolated struct CommandGlyph: Equatable {
    /// 원호 한 획. 각도는 도(degree), y가 아래로 커지는 좌표라 각도가 커지는 쪽이 화면에서 시계 방향이다.
    struct Arc: Equatable {
        let center: CGPoint
        let radius: CGFloat
        let startDegrees: CGFloat
        let endDegrees: CGFloat

        /// 원 전체를 감싸는 사각형. 상자 안에 있는지 검사할 때 쓴다(호보다 넓게 잡아 안전하다).
        var bounds: CGRect {
            CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        }
    }

    static let box = CGSize(width: 28, height: 20)
    static let fullScreen = CGRect(x: 1, y: 1, width: 26, height: 18)
    /// 채움 영역의 기준: 화면 윤곽에서 2pt 안쪽(22×14).
    static let inner = fullScreen.insetBy(dx: 2, dy: 2)
    /// 화살촉 날개 길이.
    static let arrowWing: CGFloat = 2.5

    var screen = fullScreen
    /// 디스플레이 이동의 목적지 화면.
    var secondScreen: CGRect?
    /// 창이 갈 자리(채움).
    var region: CGRect?
    /// 상대 축소의 원래 크기(점선). 채운 영역 위에 그려야 실제 크기에서 보인다.
    var ghost: CGRect?
    /// 화살표·되돌리기 기호의 직선 획. 배열 하나가 점을 잇는 한 획이다.
    var strokes: [[CGPoint]] = []
    /// 곡선 획(되돌리기의 반원). 직선 획과 같은 굵기·색으로 그린다.
    var arcs: [Arc] = []

    /// `inner` 영역의 비율 좌표 → 상자 좌표.
    static func unit(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(
            x: inner.minX + x * inner.width,
            y: inner.minY + y * inner.height,
            width: width * inner.width,
            height: height * inner.height
        )
    }

    /// 되돌리기: 위 가로선 → 오른쪽 반원 → 아래 가로선, 왼쪽 위 화살촉.
    fileprivate static let undo = Self(
        strokes: [
            [CGPoint(x: 10, y: 8), CGPoint(x: 16, y: 8)],
            [CGPoint(x: 16, y: 15), CGPoint(x: 10.5, y: 15)],
            [CGPoint(x: 12.6, y: 5.4), CGPoint(x: 10, y: 8), CGPoint(x: 12.6, y: 10.6)]
        ],
        arcs: [Arc(center: CGPoint(x: 16, y: 11.5), radius: 3.5, startDegrees: -90, endDegrees: 90)]
    )

    fileprivate static func absolute(_ placement: AbsolutePlacement) -> Self {
        let size = placement.fraction.value
        let start: CGFloat = switch placement.slot {
        case .first:
            0
        case .center:
            (1 - size) / 2
        case .last:
            1 - size
        }
        return switch placement.axis {
        case .horizontal:
            Self(region: unit(start, 0, size, 1))
        case .vertical:
            Self(region: unit(0, start, 1, size))
        }
    }

    fileprivate static func half(_ edge: SnapEdge) -> CGRect {
        switch edge {
        case .left:
            unit(0, 0, 0.5, 1)
        case .right:
            unit(0.5, 0, 0.5, 1)
        case .top:
            unit(0, 0, 1, 0.5)
        case .bottom:
            unit(0, 0.5, 1, 0.5)
        }
    }

    fileprivate static func shrink(_ anchor: RelativeAnchor, fraction: CGFloat) -> Self {
        let region = switch anchor {
        case .left:
            unit(0, 0, fraction, 1)
        case .right:
            unit(1 - fraction, 0, fraction, 1)
        case .top:
            unit(0, 0, 1, fraction)
        case .bottom:
            unit(0, 1 - fraction, 1, fraction)
        }
        return Self(region: region, ghost: unit(0, 0, 1, 1))
    }

    fileprivate static func move(_ direction: MoveDirection) -> Self {
        switch direction {
        case .left:
            Self(region: unit(0, 0.25, 0.42, 0.5), strokes: arrow(from: (23, 10), to: (17, 10)))
        case .right:
            Self(region: unit(0.58, 0.25, 0.42, 0.5), strokes: arrow(from: (5, 10), to: (11, 10)))
        case .up:
            Self(region: unit(0.29, 0, 0.42, 0.36), strokes: arrow(from: (14, 16.6), to: (14, 11.6)))
        case .down:
            Self(region: unit(0.29, 0.64, 0.42, 0.36), strokes: arrow(from: (14, 3.4), to: (14, 8.4)))
        case .center:
            Self(region: unit(0.25, 0.2, 0.5, 0.6))
        }
    }

    fileprivate static func display(_ edge: SnapEdge) -> Self {
        switch edge {
        case .left:
            Self(
                screen: CGRect(x: 14, y: 2, width: 13, height: 16),
                secondScreen: CGRect(x: 1, y: 4, width: 11, height: 12),
                region: CGRect(x: 2.6, y: 5.6, width: 7.8, height: 8.8),
                strokes: arrow(from: (24, 10), to: (18, 10))
            )
        case .right:
            Self(
                screen: CGRect(x: 1, y: 2, width: 13, height: 16),
                secondScreen: CGRect(x: 16, y: 4, width: 11, height: 12),
                region: CGRect(x: 17.6, y: 5.6, width: 7.8, height: 8.8),
                strokes: arrow(from: (4, 10), to: (10, 10))
            )
        case .top:
            Self(
                screen: CGRect(x: 5, y: 10, width: 18, height: 9),
                secondScreen: CGRect(x: 8, y: 1, width: 12, height: 6.5),
                region: CGRect(x: 9.4, y: 2.4, width: 9.2, height: 3.7),
                strokes: arrow(from: (14, 17), to: (14, 13))
            )
        case .bottom:
            Self(
                screen: CGRect(x: 5, y: 1, width: 18, height: 9),
                secondScreen: CGRect(x: 8, y: 12.5, width: 12, height: 6.5),
                region: CGRect(x: 9.4, y: 13.9, width: 9.2, height: 3.7),
                strokes: arrow(from: (14, 3), to: (14, 7))
            )
        }
    }

    /// 몸통 한 획 + 화살촉 한 획.
    private static func arrow(from tail: (CGFloat, CGFloat), to head: (CGFloat, CGFloat)) -> [[CGPoint]] {
        let start = CGPoint(x: tail.0, y: tail.1), end = CGPoint(x: head.0, y: head.1)
        let length = max(hypot(end.x - start.x, end.y - start.y), 0.001)
        let dx = (end.x - start.x) / length, dy = (end.y - start.y) / length
        let wing = arrowWing
        let back = CGPoint(x: end.x - dx * wing, y: end.y - dy * wing)
        let wingA = CGPoint(x: back.x - dy * wing, y: back.y + dx * wing)
        let wingB = CGPoint(x: back.x + dy * wing, y: back.y - dx * wing)
        return [[start, end], [wingA, end, wingB]]
    }
}

extension WindowCommand {
    /// 이 명령의 그림. 새 명령이 생기면 default 없이 여기서 컴파일이 멈춘다.
    var glyph: CommandGlyph {
        switch self {
        case .maximize:
            CommandGlyph(region: CommandGlyph.unit(0, 0, 1, 1))
        case .maximizeGaps:
            CommandGlyph(region: CommandGlyph.unit(0.14, 0.17, 0.72, 0.66))
        case let .absolute(placement):
            CommandGlyph.absolute(placement)
        case let .snapThrow(edge):
            CommandGlyph(region: CommandGlyph.half(edge))
        case let .moveToDisplay(edge):
            CommandGlyph.display(edge)
        case let .move(direction):
            CommandGlyph.move(direction)
        case let .relativeHalf(anchor):
            CommandGlyph.shrink(anchor, fraction: 1.0 / 2.0)
        case let .relativeTwoThird(anchor):
            CommandGlyph.shrink(anchor, fraction: 2.0 / 3.0)
        case .undo:
            CommandGlyph.undo
        }
    }
}
