<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-06-19 -->

# Preferences

## Purpose
사용자 설정의 영속화. UserDefaults 얇은 래퍼.

## Key Files
| File | Description |
|------|-------------|
| `PreferencesStore.swift` | `@MainActor`. `activePreset: HotkeyPreset`(키 `activeHotkeyPreset`, 기본 `.standard`), `soundFeedbackEnabled: Bool`(키 `soundFeedbackEnabled`, 미설정 시 기본 true — `object(forKey:)` nil 체크로 "미설정"과 "false" 구분) |

## For AI Agents

### Working In This Directory
- 새 설정 추가 시: private 키 상수 + computed property(get/set). Bool 기본값 true가 필요하면 `object(forKey:) != nil` 가드로 미설정을 구분(그냥 `bool(forKey:)`는 미설정 시 false).
- `@MainActor`로 통일(앱 전역 단일 인스턴스, `AppDelegate`가 보유·주입).

### Testing Requirements
- `make build` 컴파일. 동작은 라이브(프리셋 전환 → 핫키 재등록, 피드백 토글 → 비프음 on/off).

### Common Patterns
- raw 표현은 String(enum rawValue)/Bool로 저장. 읽기 실패/미설정은 안전한 기본값으로 폴백.

## Dependencies

### Internal
- `Hotkeys/HotkeyPreset`(활성 프리셋 타입). 소비처: `AppDelegate`(핫키 reload·비프음 게이팅), `Settings/ViewController`(UI).

### External
- Foundation(UserDefaults).

<!-- MANUAL: -->
