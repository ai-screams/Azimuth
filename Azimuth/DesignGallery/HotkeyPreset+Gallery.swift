//
//  HotkeyPreset+Gallery.swift
//  Azimuth
//
//  DEBUG 디자인 갤러리 전용 보조. 그림·키캡은 실제 부품(UI/CommandGlyphView, UI/KeycapsView)을 그대로 쓴다.
//

#if DEBUG
    extension HotkeyPreset {
        /// 갤러리 표본용: 이 프리셋에서 `command`의 기본 단축키.
        func galleryShortcut(for command: WindowCommand) -> HotkeyShortcut? {
            guard let binding = bindings.first(where: { $0.command == command }) else { return nil }
            return HotkeyShortcut(keyCode: binding.keyCode, modifiers: binding.modifiers)
        }
    }
#endif
