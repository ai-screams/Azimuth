<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 -->

# Notifications (명령 실패 알림)

## Purpose
명령 실패 시 사유를 담은 사용자 알림(배너)을 opt-in으로 보낸다. 알림 권한은 **절대 선요청하지
않고** Settings의 "Notify when a command fails" 토글을 켜는 순간에만 요청한다. 거부되면
`ViewController`가 토글을 되돌린다(켜져 보이는데 알림이 안 오는 상태 방지).

## Key Files
| File | Description |
|------|-------------|
| `CommandFailureNotifier.swift` | `UNUserNotificationCenter` 어댑터. `requestAuthorization([.alert])`(허용 여부 반환), `postCommandFailure(commandName:message:)`(즉시 배너), `willPresent → [.banner, .list]`(포그라운드에서도 표시) |

## For AI Agents
- 권한 요청 경로는 토글 액션(`ViewController+Actions.notifyOnFailureChanged`) 한 곳뿐이어야 한다. 앱 시작/알림 발송 시점에 권한을 요청하지 말 것.
- `ViewController`는 UserNotifications를 import하지 않는다 — `AppDelegate`가 클로저(`requestNotificationAuthorization`)로 주입한다(Sparkle과 같은 결합 회피 패턴).
- 발송 조건은 `AppDelegate.runHotkeyCommand`의 실패 분기(`preferencesStore.notifyOnCommandFailure`). transient 실패는 제외.
- 테스트: UI/시스템 연동 계층이라 `make test` 대상 아님. `make run`(서명 빌드)으로 토글 → 권한 프롬프트 → 실패 유발 → 배너 확인.

## Dependencies
- Internal: `PreferencesStore.notifyOnCommandFailure`(플래그), `WindowCommandError.userFacingMessage`(본문).
- External: UserNotifications.
