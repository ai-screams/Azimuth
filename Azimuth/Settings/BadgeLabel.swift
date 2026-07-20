//
//  BadgeLabel.swift
//  Azimuth
//
//  단축키 충돌·시스템 점유 경고용 작은 배지. 둥근 배경 + SF Symbol + 텍스트로
//  한눈에 들어오게 한다(기존 평범한 주황 텍스트 라벨을 대체).
//

import Cocoa

@MainActor
final class BadgeLabel: NSView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.cornerCurve = .continuous

        // VoiceOver에는 배지 전체를 하나의 텍스트 요소로 노출한다 — 안쪽 라벨만 읽히면
        // "Duplicate"처럼 문맥 없는 단어만 들린다. 전체 라벨은 configure에서 채운다.
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        label.setAccessibilityElement(false)
        iconView.setAccessibilityElement(false)

        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        iconView.imageScaling = .scaleProportionallyDown

        let stack = NSStackView(views: [iconView, label])
        stack.orientation = .horizontal
        stack.spacing = 3
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 11),
            iconView.heightAnchor.constraint(equalToConstant: 11)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 배지 내용을 채운다. 색은 텍스트·아이콘 틴트와 옅은 배경 모두에 쓰인다.
    func configure(text: String, symbol: String, color: NSColor) {
        label.stringValue = text
        label.textColor = color
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        iconView.contentTintColor = color
        layer?.backgroundColor = color.withAlphaComponent(0.14).cgColor
        toolTip = "\(text) — this shortcut won't trigger this command."
        setAccessibilityLabel(toolTip)
    }
}
