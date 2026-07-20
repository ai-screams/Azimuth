<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 -->

# Notifications (명령 실패 알림)

## Purpose
명령 실패 시 사유를 담은 사용자 알림(배너)을 opt-in으로 보낸다. 알림 권한은 **절대 선요청하지
않고** Settings의 "Notify when a command fails" 토글을 켜는 순간에만 요청한다. 켜지 못하면
`ViewController`가 토글을 되돌리고(켜져 보이는데 알림이 안 오는 상태 방지), **beep 없이**
`notifyApprovalLabel`로 System Settings 안내를 띄운다.

## Key Files
| File | Description |
|------|-------------|
| `CommandFailureNotifier.swift` | `UNUserNotificationCenter` 어댑터. `requestAuthorization()`→`NotificationAuthorizationResult`(`granted`/`denied`/`failed`), `postCommandFailure(commandName:message:)`(즉시 배너), `willPresent → [.banner, .list]`(포그라운드에서도 표시). 이미 `.denied`면 재요청해도 프롬프트가 안 뜨므로 요청 없이 `.denied` 반환 |
| `NotificationAuthorizationResult` | `granted`(성공) / `denied`(시스템에서 꺼짐 → System Settings 안내) / `failed`(요청 에러) 값 타입. UI가 UserNotifications를 import하지 않고도 셋을 구분 |

## For AI Agents
- 권한 요청 경로는 토글 액션(`ViewController+Actions.notifyOnFailureChanged`) 한 곳뿐이어야 한다. 앱 시작/알림 발송 시점에 권한을 요청하지 말 것.
- `ViewController`는 UserNotifications를 import하지 않는다 — `AppDelegate`가 클로저(`requestNotificationAuthorization`)로 주입한다(Sparkle과 같은 결합 회피 패턴).
- 발송 조건은 `AppDelegate.runHotkeyCommand`의 실패 분기(`preferencesStore.notifyOnCommandFailure`). transient 실패는 제외.
- 사용자가 의도적으로 누른 토글에 **beep을 울리지 말 것**(원본 Mara 패턴은 조용히 되돌림). 거부/실패는 `notifyApprovalLabel` 안내로 연결한다.
- **개발 빌드 제약(중요):** `make run`은 DerivedData에서 실행되는데, 이런 빌드는 시스템 알림에 등록되지 않아 `requestAuthorization`이 프롬프트 없이 `UNErrorDomain 1`(notificationsNotAllowed)로 실패한다(`authorizationStatus`도 프롬프트 전에 이미 `.denied`). 즉 **배너 자체는 `make run`으로 검증 불가** — 정식 서명·공증·설치된 배포 빌드에서만 프롬프트/배너가 뜬다. `.info`/`.debug` 로그는 `log show`에 안 남으니 진단은 `/usr/bin/log stream --process Azimuth`로(셸에 `log` 함수 alias가 있어 절대경로 필요).

## Dependencies
- Internal: `PreferencesStore.notifyOnCommandFailure`(플래그), `WindowCommandError.userFacingMessage`(본문).
- External: UserNotifications.
