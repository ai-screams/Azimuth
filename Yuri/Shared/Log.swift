import os

enum Log {
    static let app = Logger(subsystem: "com.aiscream.Yuri", category: "app")
    static let windows = Logger(subsystem: "com.aiscream.Yuri", category: "windows")
}
