<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# Hotkeys

## Purpose
전역 단축키. Carbon `RegisterEventHotKey`로 시스템 전역 핫키를 등록하고, 프리셋(Standard/Vim)으로 25개 명령 전체에 키 조합을 매핑한다.

## Key Files
| File | Description |
|------|-------------|
| `HotkeyService.swift` | `@MainActor` Carbon 래퍼. `register`/`unregisterAll`/`reload(_:perform:)`. 단일 `InstallEventHandler`(`GetApplicationEventTarget`) + `nonisolated` C 콜백 `hotkeyEventHandler`가 `MainActor.assumeIsolated`로 디스패치. 서명 `'YURI'` |
| `HotkeyPreset.swift` | `nonisolated`. `HotkeyBinding`(command/keyCode/modifiers) + `HotkeyPreset`(`.standard`/`.vim`). 계층형 키맵: ⌃⌥ 반분/최대화/되돌리기/중앙·숫자(1/3·2/3), ⌃⌥⌘ 이동, ⌃⌥⇧ 상대. Vim은 방향키를 H/J/K/L로, 되돌리기를 U로 |

## For AI Agents

### Working In This Directory
- 새 명령을 핫키에 노출하려면 `HotkeyPreset.bindings`에 `HotkeyBinding` 추가. 두 프리셋 모두 **키 조합 유일성** 유지(겹치면 등록이 거부/스킵됨).
- 키코드는 Carbon 가상 키코드(`kVK_*`), modifier는 Carbon 상수(`controlKey|optionKey|cmdKey|shiftKey`). NSEvent modifier와 혼동 금지.
- Carbon 콜백은 메인 런루프에서 오므로 `nonisolated` 함수 + `MainActor.assumeIsolated`로 진입(현 패턴 유지).
- 프리셋 변경 시 재등록은 `HotkeyService.reload`. `AppDelegate.reloadHotkeys`가 `PreferencesStore.activePreset`을 읽어 호출.

### Testing Requirements
- 등록은 권한/시스템 충돌 영향을 받으므로 `make run` 라이브 검증. 바인딩 유일성은 빌드 시점에 확인(겹치면 일부 등록 실패 로그).

### Common Patterns
- 등록 실패(`RegisterEventHotKey != noErr`)는 로그 + 스킵(앱 전체를 막지 않음). 시스템/타앱과 겹치는 조합은 자연 스킵 → 7c에서 커스터마이즈 예정.

## Dependencies

### Internal
- `Commands/WindowCommand`(바인딩 대상), `Preferences/PreferencesStore`(활성 프리셋, `AppDelegate` 경유), `Shared/Log`.

### External
- Carbon.HIToolbox(핫키), Cocoa, os(Logger).

<!-- MANUAL: -->
