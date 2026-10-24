//
//  CheatSheetController.swift
//  Azimuth
//
//  단축키 치트시트(#182)를 띄우고 닫는다. 수정키 변화와 키 누름을 전역 이벤트 감시로 받는다.
//  손쉬운 사용 권한만으로 다른 앱 위의 `.flagsChanged`·`.keyDown`이 오고 입력 모니터링 권한은 묻지 않는다
//  (macOS 27 서명 빌드 실기). 수정키 마스크와 "키가 눌렸다"는 사실만 쓰고, 키코드·글자는 읽지도 기록하지도 않는다.
//  언제 띄우고 닫을지는 `CheatSheetTrigger`, 어느 키에 어떤 명령인지는 `CheatSheetLayer`가 정한다.
//

import AppKit
import SwiftUI

@MainActor
final class CheatSheetController {
    /// 지금 실제로 등록된 바인딩(꺼진 명령·등록 실패 제외). 수정키가 바뀔 때마다 묻는다.
    private let bindings: () -> [HotkeyBinding]
    private var monitors: [Any] = []
    private var state = CheatSheetTrigger.State.idle
    private var timer: Timer?
    private var delay: TimeInterval = CheatSheetDelay.standard.seconds
    private lazy var panel = makePanel()

    init(bindings: @escaping () -> [HotkeyBinding]) {
        self.bindings = bindings
    }

    /// 켜기: 설정이 켜져 있고 권한이 있으며 단축키 녹화 중이 아닐 때. 끄면 감시를 떼고 패널을 닫는다.
    func setActive(_ active: Bool, delay: CheatSheetDelay) {
        self.delay = delay.seconds
        guard active != !monitors.isEmpty else { return }
        if active {
            installMonitors()
        } else {
            monitors.forEach(NSEvent.removeMonitor)
            monitors = []
            reset()
        }
    }

    /// 명령이 실행됨(단축키, 메뉴바 팝오버). 키 누름 감시가 놓치는 경로가 있어도 여기서 한 번 더 막는다.
    func commandRan() {
        handle(.keyPressed)
    }

    private func installMonitors() {
        // 다른 앱이 앞일 때는 전역, Azimuth 창(설정 등)이 앞일 때는 로컬 감시가 받는다. 로컬은 이벤트를 그대로 넘긴다.
        let flags: (NSEvent) -> Void = { [weak self] event in
            self?.modifiersChanged(CarbonModifier.mask(from: event.modifierFlags))
        }
        let keys: (NSEvent) -> Void = { [weak self] _ in self?.handle(.keyPressed) }
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags),
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keys),
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { flags($0)
                return $0
            },
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { keys($0)
                return $0
            }
        ].compactMap(\.self)
    }

    private func modifiersChanged(_ mask: UInt32) {
        let hasLayer = mask != 0 && CheatSheetLayer.make(bindings: bindings(), modifiers: mask) != nil
        handle(.modifiers(mask, hasLayer: hasLayer))
    }

    private func handle(_ event: CheatSheetTrigger.Event) {
        let (next, effect) = CheatSheetTrigger.reduce(state, event)
        state = next
        perform(effect)
    }

    private func perform(_ effect: CheatSheetTrigger.Effect) {
        switch effect {
        case .none:
            break
        case .schedule:
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.handle(.delayElapsed) }
            }
        case .cancel:
            cancelTimer()
        case let .show(mask):
            cancelTimer()
            show(mask)
        case .hide:
            cancelTimer()
            panel.orderOut(nil)
        }
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func reset() {
        cancelTimer()
        state = .idle
        panel.orderOut(nil)
    }

    private func show(_ mask: UInt32) {
        guard let layer = CheatSheetLayer.make(bindings: bindings(), modifiers: mask) else {
            panel.orderOut(nil)
            return
        }
        let hosting = NSHostingController(rootView: CheatSheetPanelContent(layer: layer))
        hosting.sizingOptions = []
        let size = hosting.sizeThatFits(in: CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: .greatestFiniteMagnitude
        ))
        let wasVisible = panel.isVisible
        panel.contentViewController = hosting
        panel.setContentSize(size)
        if !wasVisible {
            // "동작 줄이기"면 나타나는 애니메이션 없이. 보는 중에 바꿀 수 있어 띄울 때마다 읽는다.
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            panel.animationBehavior = reduceMotion ? .none : .utilityWindow
            panel.centerOnMouseScreen()
        }
        // 활성화하지 않고 앞에만 둔다. 지금 쓰는 앱이 키 입력을 계속 받아야 한다.
        panel.orderFrontRegardless()
    }

    /// 제목 없는 비활성 패널: 포커스를 뺏지 않고 클릭을 통과시킨다. 제목이 없어야 `updateActivationPolicy`가
    /// Dock 아이콘을 띄우지 않는다. 전체 화면 앱 위와 모든 Space에서 보인다.
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        return panel
    }
}

/// 패널 바탕: 시스템 재질 위에 키보드 지도.
private struct CheatSheetPanelContent: View {
    let layer: CheatSheetLayer
    private let shape = RoundedRectangle(cornerRadius: CheatSheetView.cornerRadius, style: .continuous)

    var body: some View {
        CheatSheetView(layer: layer)
            .background(.regularMaterial, in: shape)
    }
}
