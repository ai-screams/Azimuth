//
//  main.swift
//  Yuri
//
//  Programmatic AppKit entry point. The app has no storyboard, so it wires the
//  NSApplication delegate explicitly instead of relying on NSMainStoryboardFile.
//

import Cocoa

// main.swift top-level code runs on the main thread but is nonisolated, while the
// AppKit types are @MainActor — assume isolation to wire and run the app.
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
