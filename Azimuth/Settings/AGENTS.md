<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# Settings

## Purpose
설정창의 윈도우 컨트롤러. 창 생성·표시·멀티모니터 배치를 담당하고, 의존성을 내용 뷰(`ViewController`, `Azimuth/`에 위치)에 주입한다.

## Key Files
| File | Description |
|------|-------------|
| `SettingsWindowController.swift` | `@MainActor`. `init(preferencesStore:launchService:onPresetChange:)`로 의존성 주입. `show()`는 마우스가 있는 화면 중앙에 배치 후 표시(멀티모니터에서 묻힘 방지). 윈도우 컨트롤러를 캐시(단일 설정창) |

## For AI Agents

### Working In This Directory
- 설정 UI의 **내용**은 `Azimuth/ViewController.swift`에 있다(이 컨트롤러는 창 프레이밍·표시만). 새 의존성은 이 init을 통해 `ViewController`로 전달.
- 창 배치는 `NSEvent.mouseLocation`이 속한 화면 기준. 이 동작을 유지(멀티모니터 회귀 방지).

### Testing Requirements
- `make run`으로 띄워 설정창이 활성 화면 중앙에 뜨는지, 메뉴/`⌘,`/Dock 재오픈 경로가 모두 같은 창을 여는지 확인.

### Common Patterns
- 의존성 주입(DI): 싱글톤 대신 생성자 주입. 프리셋 변경은 `onPresetChange` 클로저로 `AppDelegate`에 통지([weak self]로 순환 참조 회피).

## Dependencies

### Internal
- `Azimuth/ViewController`(내용), `Preferences/PreferencesStore`, `Launch/LaunchAtLoginService`.

### External
- Cocoa(NSWindowController/NSWindow/NSScreen).

<!-- MANUAL: -->
