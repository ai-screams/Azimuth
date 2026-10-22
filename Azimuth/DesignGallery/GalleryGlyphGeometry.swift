//
//  GalleryGlyphGeometry.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리 전용: 명령 그림(#181, Outline 안)의 도형을 28×20 상자 좌표로 정한다.
//  HTML 목업에서 고른 좌표를 그대로 옮겼다. 실물 확인 뒤 #181에서 Commands/로 옮기고 하네스 테스트를 붙인다.
//

#if DEBUG
    import CoreGraphics

    nonisolated struct GalleryGlyphGeometry: Equatable {
        static let box = CGSize(width: 28, height: 20)
        static let fullScreen = CGRect(x: 1, y: 1, width: 26, height: 18)

        var screen = fullScreen
        /// 디스플레이 이동의 목적지 화면.
        var secondScreen: CGRect?
        /// 창이 갈 자리(채움).
        var region: CGRect?
        /// 상대 축소의 원래 크기(점선).
        var ghost: CGRect?
        /// 화살표 획. 배열 하나가 점을 잇는 한 획이다.
        var strokes: [[CGPoint]] = []
        /// 되돌리기 기호(반원 + 화살촉)는 곡선이라 뷰가 따로 그린다.
        var isUndo = false

        /// 새 명령이 생기면 default 없이 여기서 컴파일이 멈추게 한다.
        static func of(_ command: WindowCommand) -> Self {
            switch command {
            case .maximize:
                Self(region: unit(0, 0, 1, 1))
            case .maximizeGaps:
                Self(region: unit(0.14, 0.17, 0.72, 0.66))
            case let .absolute(placement):
                absolute(placement)
            case let .snapThrow(edge):
                Self(region: half(edge))
            case let .moveToDisplay(edge):
                display(edge)
            case let .move(direction):
                move(direction)
            case let .relativeHalf(anchor):
                shrink(anchor, fraction: 1.0 / 2.0)
            case let .relativeTwoThird(anchor):
                shrink(anchor, fraction: 2.0 / 3.0)
            case .undo:
                Self(isUndo: true)
            }
        }

        /// 화면 안쪽(1pt 여백) 22×14 영역의 비율 좌표 → 상자 좌표.
        static func unit(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: 3 + x * 22, y: 3 + y * 14, width: width * 22, height: height * 14)
        }

        private static func absolute(_ placement: AbsolutePlacement) -> Self {
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

        private static func half(_ edge: SnapEdge) -> CGRect {
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

        private static func shrink(_ anchor: RelativeAnchor, fraction: CGFloat) -> Self {
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

        private static func move(_ direction: MoveDirection) -> Self {
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

        private static func display(_ edge: SnapEdge) -> Self {
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

        /// 몸통 한 획 + 화살촉 한 획. 화살촉 날개 길이는 2.5pt.
        private static func arrow(from tail: (CGFloat, CGFloat), to head: (CGFloat, CGFloat)) -> [[CGPoint]] {
            let start = CGPoint(x: tail.0, y: tail.1), end = CGPoint(x: head.0, y: head.1)
            let length = max(hypot(end.x - start.x, end.y - start.y), 0.001)
            let dx = (end.x - start.x) / length, dy = (end.y - start.y) / length
            let back = CGPoint(x: end.x - dx * 2.5, y: end.y - dy * 2.5)
            let wingA = CGPoint(x: back.x - dy * 2.5, y: back.y + dx * 2.5)
            let wingB = CGPoint(x: back.x + dy * 2.5, y: back.y - dx * 2.5)
            return [[start, end], [wingA, end, wingB]]
        }
    }
#endif
