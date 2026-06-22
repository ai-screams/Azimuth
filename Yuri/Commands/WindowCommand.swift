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
}

nonisolated enum CommandGroup: String, CaseIterable {
    case core
    case halves
    case thirds
    case twoThirds
    case move
    case relative

    /// 설정 UI 그룹 헤더 표시명.
    var displayName: String {
        switch self {
        case .core:
            "Maximize · Undo · Center"
        case .halves:
            "Halves"
        case .thirds:
            "Thirds"
        case .twoThirds:
            "Two-Thirds"
        case .move:
            "Move"
        case .relative:
            "Relative Resize"
        }
    }

    /// 영속·식별용 안정 토큰. 저장 키이므로 한 번 출시되면 이 문자열을 바꾸지 말 것
    /// (case 이름과 분리해 두어, case 리네임이 저장된 비활성 그룹 설정을 깨지 않게 한다).
    var token: String {
        switch self {
        case .core:
            "core"
        case .halves:
            "halves"
        case .thirds:
            "thirds"
        case .twoThirds:
            "twoThirds"
        case .move:
            "move"
        case .relative:
            "relative"
        }
    }
}

nonisolated enum WindowCommand: Equatable {
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

    /// 저장·조회용 안정 식별자. 커스텀 단축키 override의 키로 쓴다.
    var identifier: String {
        switch self {
        case .maximize:
            "maximize"
        case .undo:
            "undo"
        case let .absolute(placement):
            "absolute.\(placement.axis.token).\(placement.fraction.token).\(placement.slot.token)"
        case let .move(direction):
            "move.\(direction.token)"
        case let .relativeHalf(anchor):
            "relativeHalf.\(anchor.token)"
        }
    }

    /// 식별자로 명령을 역조회한다(커스텀 단축키 디코딩용). 알 수 없으면 nil.
    /// 불변식: 역조회 대상은 `menuCommands`(25개)뿐. 여기에 없는 명령의 식별자는 복원되지 않는다.
    static func command(forIdentifier identifier: String) -> WindowCommand? {
        menuCommands.first { $0.identifier == identifier }
    }

    /// 그룹 단위 on/off용 논리 그룹.
    /// 순서 의존: `.move(.center)`가 `.move`보다 앞서야 중앙 이동이 `.core`로 분류된다.
    var group: CommandGroup {
        switch self {
        case .maximize, .undo, .move(.center):
            .core
        case .move:
            .move
        case .relativeHalf:
            .relative
        case let .absolute(placement):
            switch placement.fraction {
            case .half:
                .halves
            case .third:
                .thirds
            case .twoThird:
                .twoThirds
            }
        }
    }

    /// DEBUG 메뉴에 노출할 명령 목록. 절대 배치의 center/middle slot은 1/3에만 둔다
    /// (move(.center)는 별개의 이동 명령).
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
