//
//  DesignGalleryWindowController.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리 창. 상태바의 DEBUG 메뉴 "Design Gallery (Debug)"가 연다.
//

#if DEBUG
    import AppKit
    import SwiftUI

    final class DesignGalleryWindowController {
        private var window: NSWindow?

        func show() {
            let window = window ?? makeWindow()
            self.window = window
            NSApp.bringToFront()
            window.makeKeyAndOrderFront(nil)
        }

        private func makeWindow() -> NSWindow {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Design Gallery (Debug)"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: DesignGalleryView())
            window.center()
            return window
        }
    }
#endif
