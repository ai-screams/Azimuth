//
//  AdvancedSettingsView.swift
//  Azimuth
//
//  Advanced 화면: 실행 취소 기록(#170)과 응답 없는 앱 대기 시간. 대부분의 사용자가 건드릴 필요 없는 것만 둔다.
//

import SwiftUI

struct AdvancedSettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section("Undo") {
                BoundedIntRow(
                    title: "Undo steps per window",
                    setting: UndoHistory.depth,
                    value: model.undoDepth,
                    commit: model.commitUndoDepth,
                    step: model.setUndoDepth
                )
                BoundedIntRow(
                    title: "Windows to remember",
                    setting: UndoHistory.windowCapacity,
                    value: model.undoWindowCapacity,
                    commit: model.commitUndoWindowCapacity,
                    step: model.setUndoWindowCapacity
                )
            }
            Section {
                Picker("Wait for unresponsive apps", selection: Binding(
                    get: { model.resolveTimeout },
                    set: model.setResolveTimeout
                )) {
                    ForEach(ResolveTimeoutChoice.allCases, id: \.self) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
            } header: {
                Text("Unresponsive apps")
            } footer: {
                Text(
                    "Shorter keeps Azimuth's menus responsive when an app hangs. Longer gives slow apps more time "
                        + "to answer. Leave this alone unless commands fail on apps that are merely slow."
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
    }
}

/// 숫자 칸 + stepper. 칸의 글자는 엔터나 포커스를 잃을 때 `commit`으로 보내고, 돌려받은 저장값을 칸에 다시 쓴다.
/// 숫자가 아니면 저장하지 않으므로(`BoundedIntSetting.parse`) 칸은 원래 값으로 돌아간다. `TextField(value:format:)`는 해석 규칙이 달라 쓰지 않는다.
private struct BoundedIntRow: View {
    let title: String
    let setting: BoundedIntSetting
    let value: Int
    let commit: (String) -> Int
    let step: (Int) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, text: $text)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder) // grouped Form은 테두리를 지워 입력 칸인지 보이지 않는다
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 56)
                    .focused($focused)
                    .onSubmit { text = "\(commit(text))" }
                Stepper(title, value: Binding(get: { value }, set: step), in: setting.range)
                    .labelsHidden()
            }
        }
        .help("\(setting.range.lowerBound)–\(setting.range.upperBound)")
        .onAppear { text = "\(value)" }
        .onChange(of: value) { _, newValue in text = "\(newValue)" }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { text = "\(commit(text))" }
        }
    }
}
