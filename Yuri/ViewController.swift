//
//  ViewController.swift
//  Yuri
//
//  Created by hanyul on 3/31/26.
//

import Cocoa

final class ViewController: NSViewController {
    private let titleLabel = NSTextField(labelWithString: "Accessibility Permission")
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var actionButton = makeActionButton()
    private lazy var stackView = makeStackView()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 260))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        updatePermissionUI()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updatePermissionUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        _ = AccessibilityPermissionService.requestPrompt()

        guard AccessibilityPermissionService.openSystemSettings() else {
            NSSound.beep()
            return
        }
    }

    @objc private func handleDidBecomeActive(_ notification: Notification) {
        updatePermissionUI()
    }

    private func configureView() {
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func updatePermissionUI() {
        let status = AccessibilityPermissionService.currentStatus()

        statusLabel.stringValue = status.settingsStatusText
        statusLabel.textColor = status.isTrusted ? .systemGreen : .systemOrange
        detailLabel.stringValue = status.settingsDetailText
        actionButton.isHidden = status.isTrusted
    }

    private func makeActionButton() -> NSButton {
        let button = NSButton(
            title: "Open Accessibility Settings…",
            target: self,
            action: #selector(openAccessibilitySettings(_:))
        )
        button.bezelStyle = .rounded
        return button
    }

    private func makeStackView() -> NSStackView {
        let stackView = NSStackView(views: [titleLabel, statusLabel, detailLabel, actionButton])
        stackView.alignment = .leading
        stackView.orientation = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }
}
