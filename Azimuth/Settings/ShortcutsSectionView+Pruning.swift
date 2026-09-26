//
//  ShortcutsSectionView+Pruning.swift
//  Azimuth
//
//  Shortcuts 목록의 숨은 슬롯(구분선·그룹 머리·행)을 뷰 계층에서 떼고 다시 붙인다(#137).
//  `applyFilter`가 표시 여부를 정한 뒤 `pruneHiddenSlots()`를 부른다.
//

import Cocoa

extension ShortcutsSectionView {
    /// 숨은 슬롯은 뷰 계층에서 떼고 새로 보이는 슬롯만 제자리에 끼운다. `addArrangedSubview`로 넣은 뷰는
    /// `isHidden`이어도 계층에 남아 모두 접힌 상태에서도 뷰가 약 690개였다(탭 전환마다 AppKit이 배치·키 뷰
    /// 루프를 다시 계산) → 약 110개. 떼면 부모(rowsStack)에 걸린 폭 제약과 구분선 뒤 간격이 사라지므로
    /// 다시 끼울 때 되살린다. 떼기 전에 포커스를 옮기고, 옮기지 못한 슬롯은 이번엔 떼지 않는다.
    func pruneHiddenSlots() {
        if allSlots.isEmpty { allSlots = rowsStack.arrangedSubviews }
        var keptIDs = Set(allSlots.filter { !$0.isHidden }.map(ObjectIdentifier.init))
        if let pinned = slotKeepingFocus(leaving: keptIDs) { keptIDs.insert(pinned) }
        var membershipChanged = false
        for view in rowsStack.arrangedSubviews where !keptIDs.contains(ObjectIdentifier(view)) {
            rememberWidthConstraint(of: view)
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
            membershipChanged = true
        }
        let separators = Set(groupViews.values.map { ObjectIdentifier($0.separator) })
        let kept = allSlots.filter { keptIDs.contains(ObjectIdentifier($0)) }
        for (index, view) in kept.enumerated() where view.superview !== rowsStack {
            rowsStack.insertArrangedSubview(view, at: index)
            slotWidthConstraints[ObjectIdentifier(view)]?.isActive = true
            if separators.contains(ObjectIdentifier(view)) {
                rowsStack.setCustomSpacing(Metric.groupGap, after: view)
            }
            membershipChanged = true
        }
        // 창은 키 뷰 루프를 자동 재계산하지만(`autorecalculatesKeyViewLoop`), 떼고 붙인 직후 Tab이 바로
        // 맞도록 슬롯이 실제로 바뀐 경우에만 즉시 한 번 더 계산한다(검색 한 글자마다 하지 않게).
        if membershipChanged { window?.recalculateKeyViewLoop() }
        #if DEBUG
            assertSlotInvariants()
        #endif
    }

    /// 뗄 슬롯 안에 키보드 포커스가 있으면 검색창으로(안 되면 창으로) 옮긴다. 녹화 중인 단축키 버튼은
    /// `resignFirstResponder`에서 녹화를 취소하므로 전역 단축키가 멈춘 채 남지 않는다. 둘 다 거부되면
    /// 녹화를 직접 취소하고, 포커스가 남은 그 슬롯은 돌려줘 이번엔 떼지 않게 한다(숨긴 채 붙여 둔다).
    private func slotKeepingFocus(leaving keptIDs: Set<ObjectIdentifier>) -> ObjectIdentifier? {
        guard let window,
              let responder = window.firstResponder as? NSView,
              let slot = rowsStack.arrangedSubviews.first(where: { responder.isDescendant(of: $0) }),
              !keptIDs.contains(ObjectIdentifier(slot))
        else { return nil }
        let moveFocus = { window.makeFirstResponder(self.searchField) || window.makeFirstResponder(nil) }
        if moveFocus() { return nil }
        (responder as? ShortcutRecorderButton)?.cancelRecordingIfNeeded()
        // 거부 원인이 녹화 상태였다면 취소 뒤엔 옮겨질 수 있다 — 되면 숨긴 채 붙여 둘 슬롯이 없다.
        return moveFocus() ? nil : ObjectIdentifier(slot)
    }

    /// 뗄 슬롯의 폭 제약을 처음 한 번 기억한다(제약은 생성 지점마다 따로 만들어져 있다).
    private func rememberWidthConstraint(of view: NSView) {
        let key = ObjectIdentifier(view)
        guard slotWidthConstraints[key] == nil else { return }
        slotWidthConstraints[key] = rowsStack.constraints.first { isSlotWidthConstraint($0, of: view) }
    }

    /// "슬롯 폭 = rowsStack 폭" 제약인가(같음, 배율 1, 상수 0).
    private func isSlotWidthConstraint(_ constraint: NSLayoutConstraint, of view: NSView) -> Bool {
        let sameWidth = constraint.firstAttribute == .width && constraint.secondAttribute == .width
        let plain = constraint.relation == .equal && constraint.multiplier == 1 && constraint.constant == 0
        return sameWidth && plain && constraint.firstItem === view && constraint.secondItem === rowsStack
    }

    #if DEBUG
        /// 떼기/붙이기 불변식(Debug 전용). 앱 안 검증에서 실제 폭 버그(47행 중 34행)를 잡은 규칙들이다:
        /// 붙은 슬롯은 원래 순서를 따르고, 보이는 슬롯은 전부 붙어 있고, 숨은 채 붙은 슬롯은 포커스를 못 옮긴
        /// 경우의 하나뿐이며, 붙은 슬롯마다 활성 폭 제약이 정확히 하나다.
        private func assertSlotInvariants() {
            let attached = rowsStack.arrangedSubviews
            assert(attached == allSlots.filter { attached.contains($0) }, "slots out of canonical order")
            assert(allSlots.allSatisfy { $0.isHidden || attached.contains($0) }, "visible slot detached")
            assert(attached.filter(\.isHidden).count <= 1, "more than one hidden slot left attached")
            for view in attached {
                let widths = rowsStack.constraints.filter { $0.isActive && isSlotWidthConstraint($0, of: view) }
                assert(widths.count == 1, "slot has \(widths.count) width constraints")
            }
        }
    #endif
}
