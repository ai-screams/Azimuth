//
//  AdaptiveShapes.swift
//  Azimuth
//
//  2.0 화면의 둥근 요소와 질감(#179). macOS 26 질감의 `#available` 분기는 이 파일 한 곳에 모은다.
//  - 안쪽 둥근 요소: 바깥 모서리와 여백에서 구한 고정 반지름(`ConcentricRadius`). SwiftUI `ConcentricRectangle`은 쓰지 않는다:
//    목록 안에서는 모서리에서 먼 줄까지 바깥 반지름을 따라 알약 모양이 됐고(화면 밖 렌더링 실측, .docs 결정 기록),
//    지금 크기에서는 고정값과 같은 모양이었다.
//  - 고른 요소의 glass: 26 이상은 강조색을 옅게 섞은 interactive glass, 14–15는 강조색 바탕과 테두리.
//

import SwiftUI

enum AdaptiveShapes {
    /// 바깥 반지름 `outer`인 면 안에서 `inset`만큼 들어간 둥근 요소. 가장자리에 붙은 요소는 바깥 곡선과 중심이 같고,
    /// 모서리에서 먼 요소도 같은 반지름으로 그려 한 면 안의 모서리가 하나로 맞는다.
    static func inner(outer: CGFloat, inset: CGFloat, minimum: CGFloat = 4) -> RoundedRectangle {
        RoundedRectangle(
            cornerRadius: ConcentricRadius.inner(outer: outer, inset: inset, minimum: minimum),
            style: .continuous
        )
    }
}

extension View {
    /// 고른 요소(팝오버에서 마지막으로 적용한 명령 타일)를 표시한다. glass는 HIG대로 상호작용 요소에만, 아껴 쓴다:
    /// 모든 타일에 입히는 안과 입히지 않는 안을 디자인 갤러리에서 실기로 비교한 뒤 이 안을 골랐다(사용자 결정).
    @ViewBuilder
    func selectionGlass(_ isSelected: Bool, in shape: some Shape) -> some View {
        if #available(macOS 26.0, *), isSelected {
            glassEffect(.regular.tint(.accentColor.opacity(0.25)).interactive(), in: shape)
        } else {
            background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: shape)
                .overlay { shape.stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1) }
        }
    }
}
