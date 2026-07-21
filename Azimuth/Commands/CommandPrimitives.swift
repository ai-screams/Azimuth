//
//  CommandPrimitives.swift
//  Azimuth
//
//  WindowCommand를 구성하는 순수 값 타입(빌딩블록): 배치 축/비율/슬롯과 방향/엣지.
//  WindowCommand.swift에서 분리했다(파일 비대화 방지).
//
//  ⚠️ FrameCalculator·WindowCommand와 마찬가지로 순수 로직 파일이다.
//  AppKit/AX를 import하지 말 것 — scripts/test.sh가 이 파일을 swiftc로 직접 컴파일하므로
//  import를 추가하면 테스트 빌드가 깨진다(CoreGraphics는 허용).
//

import CoreGraphics

nonisolated enum Axis: Equatable {
    case horizontal
    case vertical

    var token: String {
        switch self {
        case .horizontal:
            "horizontal"
        case .vertical:
            "vertical"
        }
    }
}

nonisolated enum Fraction: Equatable {
    case half
    case third
    case twoThird

    var value: CGFloat {
        switch self {
        case .half:
            1.0 / 2.0
        case .third:
            1.0 / 3.0
        case .twoThird:
            2.0 / 3.0
        }
    }

    var symbol: String {
        switch self {
        case .half:
            "1/2"
        case .third:
            "1/3"
        case .twoThird:
            "2/3"
        }
    }

    var token: String {
        switch self {
        case .half:
            "half"
        case .third:
            "third"
        case .twoThird:
            "twoThird"
        }
    }
}

nonisolated enum Slot: Equatable {
    case first
    case center
    case last

    var token: String {
        switch self {
        case .first:
            "first"
        case .center:
            "center"
        case .last:
            "last"
        }
    }
}

nonisolated struct AbsolutePlacement: Equatable {
    let axis: Axis
    let fraction: Fraction
    let slot: Slot

    var displayName: String {
        "\(slotName) \(fraction.symbol)"
    }

    private var slotName: String {
        switch (axis, slot) {
        case (.horizontal, .first):
            "Left"
        case (.horizontal, .center):
            "Center"
        case (.horizontal, .last):
            "Right"
        case (.vertical, .first):
            "Top"
        case (.vertical, .center):
            "Middle"
        case (.vertical, .last):
            "Bottom"
        }
    }
}

nonisolated enum MoveDirection: Equatable {
    case left
    case right
    case up
    case down
    case center

    var displayName: String {
        switch self {
        case .left:
            "Left"
        case .right:
            "Right"
        case .up:
            "Up"
        case .down:
            "Down"
        case .center:
            "Center"
        }
    }

    /// 영속 식별자에 쓰는 안정 토큰. displayName과 분리해 UI 문구 변경이 저장 키를 깨지 않게 한다.
    var token: String {
        switch self {
        case .left:
            "left"
        case .right:
            "right"
        case .up:
            "up"
        case .down:
            "down"
        case .center:
            "center"
        }
    }
}

nonisolated enum RelativeAnchor: Equatable {
    case left
    case right
    case top
    case bottom

    var displayName: String {
        switch self {
        case .left:
            "Left"
        case .right:
            "Right"
        case .top:
            "Top"
        case .bottom:
            "Bottom"
        }
    }

    /// 영속 식별자에 쓰는 안정 토큰. displayName과 분리해 UI 문구 변경이 저장 키를 깨지 않게 한다.
    var token: String {
        switch self {
        case .left:
            "left"
        case .right:
            "right"
        case .top:
            "top"
        case .bottom:
            "bottom"
        }
    }

    /// 상대 축소가 고정해야 할 모서리. 좌/상은 origin이 그대로라 topLeft, 우/하는 반대 모서리를 고정한다.
    var frameAnchor: FrameAnchor {
        switch self {
        case .left, .top:
            .topLeft
        case .right:
            .right
        case .bottom:
            .bottom
        }
    }
}

/// frame 적용 시 실제 크기가 목표와 다를 때 어느 모서리를 고정할지의 명시적 의도.
/// 상대 축소는 앱이 요청 크기와 다르게 반올림(크기증분 앱의 셀 단위)해도 고정 모서리를 유지해야 하므로,
/// 명령이 의도를 실어 Writer로 전달한다 — 작업영역 모서리 접촉만으로는 화면 가장자리에 닿지 않은
/// 상대 축소의 고정점을 복구할 수 없다(감사 M-4).
nonisolated enum FrameAnchor: Equatable {
    /// origin 그대로 — 좌/상 고정(기본). 크기가 달라져도 origin은 목표 그대로.
    case topLeft
    /// 오른쪽 모서리 고정(너비가 목표와 달라도 target.maxX 유지).
    case right
    /// 아래쪽 모서리 고정(높이가 목표와 달라도 target.maxY 유지).
    case bottom
    /// target이 닿아 있던 작업영역 모서리를 추론해 유지(스냅·절대·최대화).
    case workAreaEdges
}

nonisolated enum SnapEdge: Equatable {
    case left
    case right
    case top
    case bottom

    /// 표시명. 기존 절대 반분과 동일하게 보여 UX 연속성을 유지한다.
    var displayName: String {
        switch self {
        case .left:
            "Left 1/2"
        case .right:
            "Right 1/2"
        case .top:
            "Top 1/2"
        case .bottom:
            "Bottom 1/2"
        }
    }

    /// 영속 식별자에 쓰는 안정 토큰.
    var token: String {
        switch self {
        case .left:
            "left"
        case .right:
            "right"
        case .top:
            "top"
        case .bottom:
            "bottom"
        }
    }

    /// 디스플레이 이동 명령 표시용 방향어(top=Up, bottom=Down).
    var displayDirection: String {
        switch self {
        case .left:
            "Left"
        case .right:
            "Right"
        case .top:
            "Up"
        case .bottom:
            "Down"
        }
    }

    /// 인접 디스플레이로 던졌을 때 진입 반대쪽 절반(우→좌, 좌→우, 위→하, 아래→위).
    var opposite: SnapEdge {
        switch self {
        case .left:
            .right
        case .right:
            .left
        case .top:
            .bottom
        case .bottom:
            .top
        }
    }
}
