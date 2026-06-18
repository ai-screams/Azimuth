import CoreGraphics

enum Axis: Equatable {
    case horizontal
    case vertical
}

enum Fraction: Equatable {
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
}

enum Slot: Equatable {
    case first
    case center
    case last
}

struct AbsolutePlacement: Equatable {
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

enum MoveDirection: Equatable {
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
}

enum RelativeAnchor: Equatable {
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
}

enum WindowCommand: Equatable {
    case maximize
    case absolute(AbsolutePlacement)
    case move(MoveDirection)
    case relativeHalf(RelativeAnchor)
    case undo

    var displayName: String {
        switch self {
        case .maximize:
            "Maximize"
        case let .absolute(placement):
            placement.displayName
        case let .move(direction):
            "Move \(direction.displayName)"
        case let .relativeHalf(anchor):
            "Shrink \(anchor.displayName) 1/2"
        case .undo:
            "Undo"
        }
    }

    /// DEBUG 메뉴에 노출할 명령 목록. center/middle은 1/3에만 둔다.
    static let menuCommands: [WindowCommand] = [
        .maximize,
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .half, slot: .first)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .half, slot: .last)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .third, slot: .first)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .third, slot: .center)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .third, slot: .last)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .twoThird, slot: .first)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .twoThird, slot: .last)),
        .absolute(AbsolutePlacement(axis: .vertical, fraction: .half, slot: .first)),
        .absolute(AbsolutePlacement(axis: .vertical, fraction: .half, slot: .last)),
        .absolute(AbsolutePlacement(axis: .vertical, fraction: .third, slot: .first)),
        .absolute(AbsolutePlacement(axis: .vertical, fraction: .third, slot: .center)),
        .absolute(AbsolutePlacement(axis: .vertical, fraction: .third, slot: .last)),
        .absolute(AbsolutePlacement(axis: .vertical, fraction: .twoThird, slot: .first)),
        .absolute(AbsolutePlacement(axis: .vertical, fraction: .twoThird, slot: .last)),
        .move(.left),
        .move(.right),
        .move(.up),
        .move(.down),
        .move(.center),
        .relativeHalf(.left),
        .relativeHalf(.right),
        .relativeHalf(.top),
        .relativeHalf(.bottom),
        .undo
    ]
}
