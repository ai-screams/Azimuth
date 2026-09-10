//
//  SettingsPaneScaffold.swift
//  Azimuth
//
//  설정 페인 공용 뼈대: 세로 스크롤뷰 + 콘텐츠 스택 + 인셋. 세 페인이 같은 구성을 쓰므로
//  한곳에 모은다. 창을 최소 높이로 줄여도 콘텐츠가 잘리지 않고 스크롤되는 성질을 여기서 보장한다.
//

import Cocoa

@MainActor
enum SettingsPaneScaffold {
    static let contentInset: CGFloat = 24
    static let sectionSpacing: CGFloat = 16

    /// `contentStack`을 스크롤뷰에 넣어 `container`에 채운다. 반환값은 자연 높이 측정용 문서 뷰.
    @discardableResult
    static func install(in container: NSView, contentStack: NSStackView) -> NSView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)
        scrollView.documentView = documentView
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            // 문서 폭을 보이는 영역에 맞춰 가로 스크롤을 막는다. 폭은 창에 고정되어 있다.
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: contentInset),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -contentInset),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: contentInset),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -contentInset)
        ])
        return documentView
    }

    /// 세로 콘텐츠 스택(카드들을 쌓는 용도).
    static func makeContentStack(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.alignment = .leading
        stack.orientation = .vertical
        stack.spacing = sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
}
