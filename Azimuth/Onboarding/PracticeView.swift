//
//  PracticeView.swift
//  Azimuth
//
//  연습 창 안의 안내(#176, 디자인 F2): "Try it · N of 3", 할 일 문장, 명령 그림, 큰 키캡, 진행 점, Skip.
//  단축키를 눌러 창이 그 자리에 가면 다음 단계로 넘어간다. 마지막은 "You're set."과 Close.
//

import SwiftUI

struct PracticeView: View {
    let model: PracticeModel
    let onClose: () -> Void

    var body: some View {
        Group {
            if let command = model.session.step.command {
                tryStep(model.session.step, command: command)
            } else {
                finished
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: model.session.step)
    }

    private func tryStep(_ step: PracticeStep, command: WindowCommand) -> some View {
        let shortcut = model.shortcut(for: command)
        return VStack(spacing: 16) {
            Text("Try it · \(step.rawValue + 1) of \(PracticeStep.tryCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            CommandGlyphView(command: command, emphasized: true, scale: 2)
                .accessibilityHidden(true)
            Text(instruction(for: step))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            KeycapsView(shortcut: shortcut)
                .scaleEffect(1.5)
                .padding(.vertical, 8)
            if shortcut == nil {
                Text("This command has no shortcut. Set one in Settings › Shortcuts, or skip.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            HStack {
                ProgressDots(current: step.rawValue, count: PracticeStep.tryCount)
                Spacer()
                Button("Skip", action: onClose)
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("You're set.")
                .font(.title2.weight(.semibold))
            Text("The same shortcuts work on any app's window. Every command is in the menu bar icon and in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Close", action: onClose)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }

    private func instruction(for step: PracticeStep) -> String {
        switch step {
        case .leftHalf:
            "Press the shortcut to snap this window to the left half."
        case .maximize:
            "Now fill the screen."
        case .undo:
            "Undo puts the window back where it was."
        case .done:
            ""
        }
    }
}

private struct ProgressDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { index in
                Circle()
                    .fill(index <= current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}
