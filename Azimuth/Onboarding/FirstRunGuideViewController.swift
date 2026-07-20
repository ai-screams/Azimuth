//
//  FirstRunGuideViewController.swift
//  Azimuth
//
//  첫 실행 안내 팝오버 콘텐츠. 시스템 권한 대화상자처럼 보이지 않게 앱 아이콘 헤더 + 안내 행으로
//  구성하고, 시맨틱 컬러만 사용해 라이트/다크에 자동 대응한다. 권한 미부여 상태면 기본 버튼이
//  "Open Settings…"로 바뀌어 Settings의 Permissions 카드로 연결된다.
//

import Cocoa
import os

@MainActor
final class FirstRunGuideViewController: NSViewController {
    private enum Layout {
        static let width: CGFloat = 300
        static let padding: CGFloat = 16
        static let sectionSpacing: CGFloat = 14
        static let rowSpacing: CGFloat = 9
        static let iconColumnWidth: CGFloat = 18
        static let headerIconSize: CGFloat = 44
        static var contentWidth: CGFloat {
            width - padding * 2
        }
    }

    private let launchService: LaunchAtLoginService
    private let needsPermission: Bool
    private let onOpenSettings: () -> Void
    private let onDone: () -> Void

    init(
        launchService: LaunchAtLoginService,
        needsPermission: Bool,
        onOpenSettings: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.launchService = launchService
        self.needsPermission = needsPermission
        self.onOpenSettings = onOpenSettings
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let stack = NSStackView(
            views: [makeHeader(), makeGuideRows(), makeLaunchAtLoginCheckbox(), makePrimaryButton()]
        )
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: Layout.width),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Layout.padding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Layout.padding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Layout.padding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Layout.padding)
        ])
        view = container
        preferredContentSize = container.fittingSize
    }

    // MARK: - Subview factories

    /// 앱 아이콘 + 타이틀을 가로 중앙에 배치한 헤더.
    private func makeHeader() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: Layout.headerIconSize),
            icon.heightAnchor.constraint(equalToConstant: Layout.headerIconSize)
        ])

        let title = NSTextField(labelWithString: "Azimuth lives in your menu bar")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .labelColor

        let header = NSStackView(views: [icon, title])
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 6
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        return header
    }

    private func makeGuideRows() -> NSView {
        var rows = [
            makeGuideRow(
                symbol: "macwindow.on.rectangle",
                tint: .secondaryLabelColor,
                text: "Click the menu bar icon for commands and settings."
            ),
            makeGuideRow(
                symbol: "keyboard",
                tint: .secondaryLabelColor,
                text: "Move and resize windows from anywhere with global shortcuts."
            )
        ]
        if needsPermission {
            rows.append(makeGuideRow(
                symbol: "exclamationmark.triangle.fill",
                tint: .systemOrange,
                text: "Accessibility permission is required before Azimuth can control windows."
            ))
        }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.rowSpacing
        return stack
    }

    private func makeGuideRow(symbol: String, tint: NSColor, text: String) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        icon.contentTintColor = tint
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: Layout.iconColumnWidth).isActive = true

        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = Layout.contentWidth - Layout.iconColumnWidth - Layout.rowSpacing

        let row = NSStackView(views: [icon, label])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = Layout.rowSpacing
        return row
    }

    private func makeLaunchAtLoginCheckbox() -> NSButton {
        let checkbox = NSButton(
            checkboxWithTitle: "Launch Azimuth at login",
            target: self,
            action: #selector(launchAtLoginChanged(_:))
        )
        checkbox.state = launchService.isEnabled ? .on : .off
        return checkbox
    }

    private func makePrimaryButton() -> NSButton {
        let button = NSButton.rounded(
            title: needsPermission ? "Open Settings…" : "Got it",
            target: self,
            action: #selector(primaryButtonClicked(_:))
        )
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        return button
    }

    // MARK: - Actions

    /// Settings의 Behavior 카드와 같은 정공법 경로(SMAppService). 등록 실패 시 체크 상태를 되돌려
    /// "켜진 것처럼 보이는데 실제로는 등록 안 됨"을 방지한다. 승인 필요 상태 안내는 Settings가 담당.
    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        if sender.state == .on {
            do {
                try launchService.enable()
            } catch {
                sender.state = .off
                NSSound.beep()
                Log.app.error(
                    "First-run guide failed to register login item: \(error.localizedDescription, privacy: .public)"
                )
            }
        } else {
            launchService.disable()
        }
    }

    @objc private func primaryButtonClicked(_ sender: Any?) {
        if needsPermission {
            onOpenSettings()
        }
        onDone()
    }
}
