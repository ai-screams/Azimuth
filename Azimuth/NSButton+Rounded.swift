//
//  NSButton+Rounded.swift
//  Azimuth
//
//  여러 곳에서 반복하던 "둥근(.rounded) 푸시 버튼 생성" 보일러플레이트를 한곳에 모은다.
//

import Cocoa

extension NSButton {
    /// title·target·action을 받아 `.rounded` bezel 스타일 푸시 버튼을 만든다.
    static func rounded(title: String, target: Any?, action: Selector?) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        return button
    }
}
