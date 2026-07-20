<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 -->

# Onboarding (첫 실행 안내)

## Purpose
첫 실행 시 상태바 아이콘에 앵커한 안내 팝오버로 메뉴바 상주·전역 단축키를 소개하고,
Accessibility 권한이 없으면 Settings의 Permissions 카드로 연결한다. `AppDelegate`의
`showFirstRunOnboardingIfNeeded()`가 `PreferencesStore.didCompleteFirstRun` 플래그로 1회만 띄운다.

## Key Files
| File | Description |
|------|-------------|
| `FirstRunGuidePresenter.swift` | `NSPopover`(.transient) presenter. `.accessory` 앱에서 바깥 클릭 dismiss는 앱이 활성일 때만 동작하므로 표시 직전 `NSApp.activate()`. 닫힘 경로 2개(기본 버튼/바깥 클릭)를 `popoverDidClose`에서 일괄 해제 |
| `FirstRunGuideViewController.swift` | 프로그래매틱 AppKit 콘텐츠(앱 아이콘 헤더 + 안내 행 + Launch at Login 체크박스 + 기본 버튼). 시맨틱 컬러만 사용(라이트/다크 자동). 권한 미부여면 기본 버튼이 "Open Settings…" |

## For AI Agents
- 팝오버 표시 플래그는 닫힘이 아니라 **표시 결정 시점에 기록**한다(크래시 시 재표시 루프 방지). 흐름을 바꾸면 이 속성을 유지할 것.
- 상태바 버튼을 얻지 못하면(메뉴바 슬롯 부족) 권한 미부여 시 Settings 창 오픈으로 폴백한다 — `AppDelegate.showFirstRunOnboardingIfNeeded()` 참조.
- 테스트: UI 전용 계층이라 `make test` 대상 아님. 시각 확인은 `defaults delete <bundle-id> didCompleteFirstRun` 후 `make run`.

## Dependencies
- Internal: `LaunchAtLoginService`(체크박스), `AccessibilityPermissionService`(권한 상태), `StatusBarController.statusButton`(앵커), `PreferencesStore.didCompleteFirstRun`(1회 플래그).
- External: AppKit.
