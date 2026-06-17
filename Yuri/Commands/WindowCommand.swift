enum WindowCommand: CaseIterable {
    case maximize
    case leftHalf
    case topHalf

    var displayName: String {
        switch self {
        case .maximize:
            "Maximize"
        case .leftHalf:
            "Left Half"
        case .topHalf:
            "Top Half"
        }
    }
}
