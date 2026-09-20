<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-20 -->

# Settings

## Purpose
설정창. 툴바 탭 3개(**General / Shortcuts / Advanced**)로 나뉜다 — 카드를 한 세로 스크롤에 쌓으면 단축키 34개 때문에 창이 1,100pt를 넘겨 열리던 문제(#113)를 없애기 위해서다. 윈도우 컨트롤러는 창 생성·표시·멀티모니터 배치만, 탭 컨테이너는 페인 소유와 창 높이 협상, 각 페인은 자기 카드만 맡는다. General 페인 본체는 `Azimuth/GeneralPaneViewController.swift`에 있다(역사적 위치).

## Key Files
| File | Description |
|------|-------------|
| `SettingsWindowController.swift` | `@MainActor`. 의존성을 생성자로 받아 페인 3개를 만들고 `SettingsTabController`를 창의 `contentViewController`로 둔다. `show()`는 마우스가 있는 화면 중앙에 배치 후 표시. 윈도우 컨트롤러를 캐시(단일 설정창). `applyResizeLimits`의 첫 `setContentSize`는 페인 폭을 확정하는 **필수** 호출(주석 참조) |
| `SettingsTabController.swift` | `NSTabViewController(tabStyle: .toolbar)`. `SettingsPane` 프로토콜(`naturalContentHeight()`·`paneTitle`·`paneSymbolName`) 정의. 탭 전환 시 `resizeWindowToSelectedPane()`으로 창 높이를 선택 페인의 자연 높이(≥ `minWindowHeight` 400)에 맞추고 `contentMaxSize`도 같이 갱신. 창 폭 상수 `windowWidth`(560)의 단일 출처. 페인 조회는 `tabViewItems` 기반(별도 배열 없음) |
| `SettingsPaneScaffold.swift` | 페인 공용 뼈대: 세로 스크롤뷰 + `FlippedView` 문서 뷰 + 콘텐츠 스택 + 인셋 24. 세 페인이 모두 사용(3중 중복 방지). 반환된 문서 뷰의 높이가 자연 높이다 |
| `ShortcutsPaneViewController.swift` | Shortcuts 탭. `ShortcutsSectionView`를 카드에 담아 호스팅. `viewWillAppear`에서 그룹을 전부 접고(`collapseAllGroups`) 창을 다시 맞춘다. 삼각형 토글(`onExpansionChanged`) 때도 `parent as? SettingsTabController`로 창 높이를 재조정 — 최대 높이가 접힌 높이에 묶이는 것을 막는다 |
| `AdvancedPaneViewController.swift` | Advanced 탭. "Wait for unresponsive apps" 해석 상한 팝업(`ResolveTimeoutChoice`) + 설명. 값 변경은 `setResolveTimeout` 클로저로 앱에 전달(`WindowAccess`를 직접 건드리지 않음) |
| `ShortcutsSectionView.swift` / `+Layout.swift` | 프리셋 세그먼트 + 검색 + 명령 34행(레코더·Reset·변경 점·충돌/점유 배지). 그룹 헤더는 **삼각형(접기, 표시 전용)** 과 **체크박스(그 그룹 핫키 등록 on/off)** 두 컨트롤 — 의미가 달라 접근성 레이블로 구분. 접힘 상태는 저장하지 않는다. 행·헤더·구분선 표시 판정은 `Commands/ShortcutListPolicy`(순수, 테스트)에 위임하고 뷰는 적용만 한다. 검색 중엔 매칭 그룹을 자동으로 펼친다 |
| `SettingsCard.swift` / `BadgeLabel.swift` / `ShortcutRecorderButton.swift` | 카드 컨테이너(심볼+제목+본문), 상태 배지, 단축키 녹화 버튼(녹화 중 전역 핫키 정지 콜백) |

## For AI Agents

### Working In This Directory
- 새 설정 항목은 **탭을 먼저 고른다**: 일반 사용자용은 General, 단축키 관련은 Shortcuts, 기본값을 건드릴 필요가 없는 것은 Advanced(구조로 "안 와도 된다"는 신호). 페인이 필요한 의존성만 생성자로 받는다 — 무엇에 의존하는지가 시그니처로 드러난다.
- 페인의 `loadView` 폭은 `SettingsTabController.windowWidth`를 쓴다. 폭이 어긋나면 자연 높이가 틀린 폭 기준으로 계산되는데 하네스가 잡지 못한다.
- 창 높이는 **AppKit이 화면 visibleFrame에 자동으로 클램프**한다(`NSWindow.constrainFrameRect`). 수동 클램프를 넣지 말 것 — 실측 근거는 내부 기록 참조. 넘치는 콘텐츠는 페인 스크롤뷰가 받는다.
- 검색·접힘 상호작용을 바꾸려면 뷰가 아니라 `Commands/ShortcutListPolicy`와 그 테스트를 고친다.
- 창 배치는 `NSEvent.mouseLocation`이 속한 화면 기준. 이 동작을 유지(멀티모니터 회귀 방지).

### Testing Requirements
- `make lint` + `make test`(`ShortcutListPolicy`) + 컴파일. 사람 확인(`make run`): 세 탭 전환 시 창 높이가 따라오는가, Shortcuts 탭이 접힌 채 짧게 열리는가, 삼각형으로 펼치면 창이 늘고 체크박스는 여전히 그룹 핫키를 끄는가, 검색이 매칭 그룹을 자동으로 펼치는가, 최소 높이(400)로 줄였을 때 각 탭이 스크롤되는가, 메뉴/`⌘,`/Dock 재오픈이 같은 창을 여는가.

### Common Patterns
- 의존성 주입(DI): 싱글톤 대신 생성자 주입. 앱 쪽 통지는 클로저(`onHotkeysChanged`·`setHotkeysSuspended`·`setResolveTimeout`·`checkForUpdates`)로, `[weak self]`로 순환 참조 회피.
- 페인의 `naturalContentHeight()`는 `documentView`가 없으면 `assertionFailure` 후 `minWindowHeight`를 돌려준다 — 0을 흘리면 400pt 창이 "성공"처럼 보이기 때문.

## Dependencies

### Internal
- `Azimuth/GeneralPaneViewController`(General 페인), `Commands/ShortcutListPolicy`, `Preferences/PreferencesStore`, `Launch/LaunchAtLoginService`, `Hotkeys/BindingResolver`·`HotkeyPreset`, `Shared/AXMessagingTimeout`(`ResolveTimeoutChoice`), `FlippedView`.

### External
- Cocoa(NSWindowController/NSWindow/NSScreen/NSTabViewController/NSStackView).

<!-- MANUAL: -->
