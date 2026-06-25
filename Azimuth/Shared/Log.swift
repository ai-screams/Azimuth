import os

enum Log {
    static let app = Logger(subsystem: "com.aiscream.Azimuth", category: "app")
    static let windows = Logger(subsystem: "com.aiscream.Azimuth", category: "windows")
}
