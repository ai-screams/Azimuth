//
//  SettingsCard.swift
//  Azimuth
//
//  설정 화면의 섹션 카드를 만든다. 제목 앞 SF Symbol 아이콘 + 은은한 배경 채움으로
//  창 배경 위에 떠 보이는 Tahoe 그룹 카드 스타일을 준다.
//

import Cocoa

@MainActor
enum SettingsCard {
    private enum Metric {
        static let contentSpacing: CGFloat = 8
        static let padding: CGFloat = 16
        static let cornerRadius: CGFloat = 10
        static let borderWidth: CGFloat = 1
        static let minWidth: CGFloat = 512
        static let titleFontSize: CGFloat = 15
        static let iconSize: CGFloat = 15
        static let headerSpacing: CGFloat = 6
    }

    /// `symbolName` 아이콘 + `title` 헤더를 얹고, `bodyViews`를 세로로 쌓은 카드(NSBox).
    static func make(symbolName: String, title: String, bodyViews: [NSView]) -> NSBox {
        let header = makeHeader(symbolName: symbolName, title: title)

        let stackView = NSStackView(views: [header] + bodyViews)
        stackView.alignment = .leading
        stackView.orientation = .vertical
        stackView.spacing = Metric.contentSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(
            top: Metric.padding, left: Metric.padding, bottom: Metric.padding, right: Metric.padding
        )

        let box = NSBox()
        box.boxType = .custom
        box.borderType = .lineBorder
        box.cornerRadius = Metric.cornerRadius
        box.borderWidth = Metric.borderWidth
        box.borderColor = .separatorColor
        box.fillColor = .controlBackgroundColor // 창 배경 위에 떠 보이는 카드 채움.
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stackView)

        if let contentView = box.contentView {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                box.widthAnchor.constraint(greaterThanOrEqualToConstant: Metric.minWidth)
            ])
        }
        return box
    }

    private static func makeHeader(symbolName: String, title: String) -> NSStackView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: Metric.titleFontSize, weight: .semibold)

        let header = NSStackView(views: [icon, titleLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = Metric.headerSpacing
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: Metric.iconSize),
            icon.heightAnchor.constraint(equalToConstant: Metric.iconSize)
        ])
        return header
    }
}
