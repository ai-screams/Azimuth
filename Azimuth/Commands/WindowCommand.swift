//
//  WindowCommand.swift
//  Azimuth
//
//  명령 모델(WindowCommand) + 논리 그룹(CommandGroup). 구성 값 타입
//  (Axis/Fraction/Slot/AbsolutePlacement/MoveDirection/RelativeAnchor/SnapEdge)은
//  CommandPrimitives.swift로 분리했다(파일 비대화 방지).
//
//  ⚠️ 순수 로직 파일 — AppKit/AX를 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//

import CoreGraphics

nonisolated enum CommandGroup: String, CaseIterable {
    case core
    case halves
    case thirds
    case twoThirds
    case move
    case relative
    case display

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
        case .display:
            "Displays"
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
        case .display:
            "display"
        }
    }
}

nonisolated enum WindowCommand: Equatable {
    case maximize
    case absolute(AbsolutePlacement)
    case snapThrow(SnapEdge)
    case moveToDisplay(SnapEdge)
    case move(MoveDirection)
    case relativeHalf(RelativeAnchor)
    case undo

    var displayName: String {
        switch self {
        case .maximize:
            "Maximize"
        case let .absolute(placement):
            placement.displayName
        case let .snapThrow(edge):
            edge.displayName
        case let .moveToDisplay(edge):
            "Move to \(edge.displayDirection) Display"
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
        case let .snapThrow(edge):
            "snapThrow.\(edge.token)"
        case let .moveToDisplay(edge):
            "moveToDisplay.\(edge.token)"
        case let .move(direction):
            "move.\(direction.token)"
        case let .relativeHalf(anchor):
            "relativeHalf.\(anchor.token)"
        }
    }

    /// 식별자로 명령을 역조회한다(커스텀 단축키 디코딩용). 알 수 없으면 nil.
    /// 불변식: 역조회 대상은 `menuCommands`(29개)뿐. 여기에 없는 명령의 식별자는 복원되지 않는다.
    static func command(forIdentifier identifier: String) -> WindowCommand? {
        menuCommands.first { $0.identifier == identifier }
    }

    /// 그룹 단위 on/off용 논리 그룹.
    /// 순서 의존: `.move(.center)`가 `.move`보다 앞서야 중앙 이동이 `.core`로 분류된다.
    var group: CommandGroup {
        switch self {
        case .maximize, .undo, .move(.center):
            .core
        case .snapThrow:
            .halves
        case .moveToDisplay:
            .display
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
        .snapThrow(.left),
        .snapThrow(.right),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .third, slot: .first)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .third, slot: .center)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .third, slot: .last)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .twoThird, slot: .first)),
        .absolute(AbsolutePlacement(axis: .horizontal, fraction: .twoThird, slot: .last)),
        .snapThrow(.top),
        .snapThrow(.bottom),
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
        .moveToDisplay(.left),
        .moveToDisplay(.right),
        .moveToDisplay(.top),
        .moveToDisplay(.bottom),
        .undo
    ]
}
