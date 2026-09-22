<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-22 -->

# Launch

## Purpose
Launch at login. Registration and deregistration go only through macOS's official `ServiceManagement.SMAppService` — no workarounds.

## Key Files
| File | Description |
|------|-------------|
| `LaunchAtLoginService.swift` | `@MainActor`. A wrapper over `SMAppService.mainApp`: `isEnabled` (status == .enabled), `requiresApproval` (status == .requiresApproval), `enable() throws` (`register()`), `disable(completion:)` (asynchronous `unregister`, calling back on the main actor when done), and `openSystemSettingsLoginItems()` |

## For AI Agents

### Working In This Directory
- **Use only the official SMAppService API.** When registration fails or reports `requiresApproval`, do not work around it — send the user to `openSystemSettingsLoginItems()` for approval.
- `unregister` is asynchronous. Do not read the state synchronously right after it; refresh the UI in the completion callback (a main-actor hop). `register()` is synchronous.
- SMAppService has no state-change notification, so the UI syncs by polling on `didBecomeActive` and when shown (see the consumer, `GeneralPaneViewController`).

### Testing Requirements
- Check the box in a `make run` (signed) build and confirm Azimuth appears under **System Settings › General › Login Items**. This works correctly only with stable signing.

### Common Patterns
- Errors are logged and surfaced to the user at the call site. `enable() throws` propagates the `SMAppService.register()` error as-is.

## Dependencies

### Internal
- Consumers: `Settings` (injection) and `GeneralPaneViewController` (the toggle UI), plus `Shared/Log`.

### External
- ServiceManagement (SMAppService), os.

<!-- MANUAL: -->
