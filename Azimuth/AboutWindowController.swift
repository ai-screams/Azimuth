//
//  AboutWindowController.swift
//  Azimuth
//
//  커스텀 About 창. 표준 패널(텍스트 전용) 대신 앱 아이콘·이름·버전·설명과
//  액션 버튼(홈페이지·이슈·후원)을 담은 정돈된 창을 코드로 구성한다.
//  버전은 번들(CFBundleShortVersionString/CFBundleVersion)에서 읽어 릴리스 빌드와
//  자동으로 일치한다. 단일 인스턴스를 재사용해 여러 번 열어도 창이 쌓이지 않는다.
//

import AppKit

@MainActor
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private static let appName = "Azimuth"
    private static let tagline =
        "A keyboard-driven window manager for macOS. Snap, throw, and arrange windows "
            + "across your displays with predictable shortcuts — no mouse, no guesswork."

    private struct Link {
        let title: String
        let symbol: String
        let url: String
        let tint: NSColor?
    }

    private static let links: [Link] = [
        Link(title: "Homepage", symbol: "globe",
             url: "https://ai-screams.github.io/Azimuth/", tint: nil),
        Link(title: "Report an Issue", symbol: "ladybug",
             url: "https://github.com/ai-screams/Azimuth/issues/new", tint: nil),
        Link(title: "Sponsor", symbol: "heart.fill",
             url: "https://github.com/sponsors/pignuante", tint: .systemPink),
        Link(title: "Buy Me a Coffee", symbol: "cup.and.saucer.fill",
             url: "https://buymeacoffee.com/pignuante", tint: .systemOrange)
    ]

    private static let contentWidth: CGFloat = 460

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.contentWidth, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.title = "About \(Self.appName)"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let content = makeContentView()
        window.contentView = content
        window.setContentSize(content.fittingSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// About 창을 화면 중앙에 전면으로 띄운다(이미 떠 있으면 앞으로 가져온다).
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window, !window.isVisible { window.center() }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func makeContentView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 30, left: 36, bottom: 26, right: 36)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(iconView())
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[0])
        stack.addArrangedSubview(label(Self.appName, font: .systemFont(ofSize: 24, weight: .bold)))
        stack.addArrangedSubview(label(versionString(), font: .systemFont(ofSize: 11),
                                       color: .secondaryLabelColor))
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[2])
        stack.addArrangedSubview(taglineLabel())
        stack.setCustomSpacing(20, after: stack.arrangedSubviews[3])
        stack.addArrangedSubview(buttonRow([Self.links[0], Self.links[1]]))
        stack.addArrangedSubview(buttonRow([Self.links[2], Self.links[3]]))
        stack.setCustomSpacing(20, after: stack.arrangedSubviews[5])
        stack.addArrangedSubview(label(copyrightString(), font: .systemFont(ofSize: 10),
                                       color: .tertiaryLabelColor))

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: Self.contentWidth)
        ])
        return container
    }

    private func iconView() -> NSView {
        let image = NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)
        let view = NSImageView(image: image ?? NSImage())
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 96),
            view.heightAnchor.constraint(equalToConstant: 96)
        ])
        return view
    }

    private func taglineLabel() -> NSTextField {
        let field = label(Self.tagline, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        field.alignment = .center
        field.maximumNumberOfLines = 0
        field.lineBreakMode = .byWordWrapping
        let width = Self.contentWidth - 72 // 좌우 인셋(36*2) 제외.
        field.preferredMaxLayoutWidth = width
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        return field
    }

    private func buttonRow(_ links: [Link]) -> NSStackView {
        let row = NSStackView(views: links.map(makeButton))
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10
        let width = Self.contentWidth - 72
        row.widthAnchor.constraint(equalToConstant: width).isActive = true
        return row
    }

    private func makeButton(_ link: Link) -> NSButton {
        let button = NSButton.rounded(title: "  \(link.title)", target: self, action: #selector(openLink(_:)))
        button.image = NSImage(systemSymbolName: link.symbol, accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.identifier = NSUserInterfaceItemIdentifier(link.url)
        if let tint = link.tint { button.contentTintColor = tint }
        return button
    }

    // MARK: - Helpers

    private func label(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.alignment = .center
        return field
    }

    private func versionString() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? ""
        if build.isEmpty || build == short { return "Version \(short)" }
        return "Version \(short) (\(build))"
    }

    private func copyrightString() -> String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© 2026 ai-screams"
    }

    @objc private func openLink(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }
}
