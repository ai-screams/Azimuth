//
//  FlippedView.swift
//  Azimuth
//
//  위에서부터 콘텐츠가 쌓이도록 뒤집힌 좌표계를 쓰는 NSView. 스크롤뷰의 documentView로 쓰면
//  콘텐츠가 위에서부터 채워진다(기본 NSView는 원점이 좌하단이라 아래에서부터 쌓여 어색하다).
//

import Cocoa

final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
