//
//  BoundedIntSetting.swift
//  Azimuth
//
//  범위와 기본값이 있는 정수 설정 하나(#170: Undo 단계 수, 기억하는 창 수).
//
//  저장 값은 손으로 편집될 수 있고 설정 화면의 숫자 칸에는 아무 글자나 들어올 수 있으므로, 읽는 쪽·쓰는 쪽·입력 칸이
//  모두 이 값 하나의 `clamped` / `parse`를 거친다. 순수 로직 — scripts/harness-sources.sh에 있다.
//

import Foundation

nonisolated struct BoundedIntSetting: Equatable {
    let range: ClosedRange<Int>
    let defaultValue: Int

    func clamped(_ value: Int) -> Int {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }

    /// 숫자 칸에 입력된 글자를 값으로 바꾼다. 범위 밖 숫자는 clamp하고, 숫자가 아니면(빈 칸·글자·Int를 넘는 수) nil —
    /// 호출부는 저장된 값을 다시 보여 준다. `NSTextField.integerValue`는 "abc"를 0으로 읽어 최솟값으로 바꿔 버린다.
    func parse(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).map(clamped)
    }
}
