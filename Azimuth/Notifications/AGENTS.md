<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-09-22 -->

# Notifications (command failure alerts)

## Purpose
Sends an opt-in user notification (a banner) carrying the reason when a command fails. Notification authorization is **never requested up front** — only at the moment the user switches on "Notify when a command fails" in Settings. If it cannot be enabled, `GeneralPaneViewController` reverts the toggle (so it never looks on while no notifications arrive) and, **without beeping**, points at System Settings through `notifyApprovalLabel`.

## Key Files
| File | Description |
|------|-------------|
| `CommandFailureNotifier.swift` | A `UNUserNotificationCenter` adapter. `requestAuthorization()` → `NotificationAuthorizationResult` (`granted` / `denied` / `failed`), `postCommandFailure(commandName:message:)` (an immediate banner), and `willPresent → [.banner, .list]` so it shows in the foreground too. When the status is already `.denied`, re-requesting shows no prompt, so it returns `.denied` without asking |
| `NotificationAuthorizationResult` | The value type `granted` (success) / `denied` (switched off in the system → point at System Settings) / `failed` (the request errored). Lets the UI tell the three apart without importing UserNotifications |

## For AI Agents
- The authorization request must have exactly one path: the toggle action (`GeneralPane+Actions.notifyOnFailureChanged`). Never request it at app start or when posting a notification.
- `GeneralPaneViewController` does not import UserNotifications — `AppDelegate` injects the `requestNotificationAuthorization` closure (the same decoupling pattern used for Sparkle).
- Posting is gated in `AppDelegate.runHotkeyCommand`'s failure branch by `preferencesStore.notifyOnCommandFailure`. Transient failures are excluded.
- **Do not beep** for a toggle the user pressed deliberately — revert it quietly and route a denial or failure to the `notifyApprovalLabel` guidance.
- **Development-build limitation (important):** `make run` launches from DerivedData, and such a build is not registered with the notification system, so `requestAuthorization` fails with `UNErrorDomain 1` (notificationsNotAllowed) without ever showing a prompt (`authorizationStatus` is already `.denied` before any prompt). In other words **the banner itself cannot be verified with `make run`** — the prompt and banner appear only in a properly signed, notarized, installed build. `.info` / `.debug` logs do not land in `log show`, so diagnose with `/usr/bin/log stream --process Azimuth` (the absolute path is needed because the shell aliases `log`).

## Dependencies
- Internal: `PreferencesStore.notifyOnCommandFailure` (the flag), `WindowCommandError.userFacingMessage` (the body).
- External: UserNotifications.
