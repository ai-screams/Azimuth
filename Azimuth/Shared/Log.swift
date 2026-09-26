import os

/// macOS 10.13~ 레거시판용 로거. `os.Logger`(11+)와 같은 호출 모양(`Log.app.error("… \(x, privacy: .public)")`)을
/// 유지해 호출부를 바꾸지 않는다. 내부는 `os_log`(10.12+). `privacy:`가 없는 보간이 하나라도 있으면 전체를 private로 남긴다.
nonisolated enum LogPrivacy: Sendable { case auto, `public`, `private` }

nonisolated struct LogMessage: ExpressibleByStringInterpolation, Sendable {
    struct StringInterpolation: StringInterpolationProtocol {
        var text = ""
        var allPublic = true
        init(literalCapacity: Int, interpolationCount: Int) {
            text.reserveCapacity(literalCapacity + interpolationCount * 8)
        }

        mutating func appendLiteral(_ literal: String) {
            text += literal
        }

        mutating func appendInterpolation(_ value: some Any, privacy: LogPrivacy = .auto) {
            text += "\(value)"
            if privacy != .public { allPublic = false }
        }
    }

    let text: String
    let isPublic: Bool
    init(stringLiteral value: String) {
        text = value
        isPublic = true
    }

    init(stringInterpolation: StringInterpolation) {
        text = stringInterpolation.text
        isPublic = stringInterpolation.allPublic
    }
}

nonisolated struct LegacyLogger: Sendable {
    let log: OSLog
    init(subsystem: String, category: String) {
        log = OSLog(subsystem: subsystem, category: category)
    }

    private func emit(_ message: LogMessage, _ type: OSLogType) {
        if message.isPublic {
            os_log("%{public}@", log: log, type: type, message.text)
        } else {
            os_log("%{private}@", log: log, type: type, message.text)
        }
    }

    func debug(_ message: LogMessage) {
        emit(message, .debug)
    }

    func info(_ message: LogMessage) {
        emit(message, .info)
    }

    func error(_ message: LogMessage) {
        emit(message, .error)
    }
}

nonisolated enum Log {
    static let app = LegacyLogger(subsystem: "com.aiscream.Azimuth", category: "app")
    static let windows = LegacyLogger(subsystem: "com.aiscream.Azimuth", category: "windows")
}
