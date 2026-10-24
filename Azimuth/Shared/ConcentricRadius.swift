//
//  ConcentricRadius.swift
//  Azimuth
//
//  동심 모서리(#179)의 반지름 계산. 바깥 모서리 반지름에서 안쪽 요소까지의 거리를 빼면 두 곡선의 중심이 같아진다.
//  모든 OS에서 이 값을 쓴다(`UI/AdaptiveShapes`, `ConcentricRectangle`을 쓰지 않는 이유도 거기).
//

import CoreGraphics

nonisolated enum ConcentricRadius {
    /// 바깥 반지름 `outer`, 바깥 가장자리에서 `inset`만큼 들어간 요소의 반지름. 너무 깊이 들어가 0에 가까워지면
    /// 각진 모양이 되지 않게 `minimum`을 지킨다.
    static func inner(outer: CGFloat, inset: CGFloat, minimum: CGFloat) -> CGFloat {
        max(minimum, outer - inset)
    }
}
