<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-10-24 | Updated: 2026-10-24 -->

# Palette

## Purpose
The command palette (#183). A shortcut (default ⌃⌥P, set in Settings → Shortcuts) opens a search panel at the top of the screen holding the target window. Typing filters the 34 commands by name and alias, ↑↓ moves the selection and draws a dashed outline where the window would go, Return runs the command on the app that was in front, Esc or a click elsewhere closes it.

## Key Files
| File | Description |
|------|-------------|
| `CommandPalettePolicy.swift` | Pure, in the harness. `CommandPaletteSearch` (word aliases; every query word must prefix-match a name word, group name or alias; rank name start > name words > alias or group, then recent, then menu order; the core group's name is a list of commands and is not searched), `CommandPaletteSelection` (clamps, no wrap), `CommandPaletteRecents` (palette runs only, newest first, 5), `CommandPalettePreview` (the outline frame through the same `CommandPlanPolicy` and `FixedSizePlacementPolicy` as execution; nil for Undo and display moves) and `CommandPaletteShortcut` (identifier `commandPalette`, default ⌃⌥P, conflicts with command bindings) |
| `CommandPaletteController.swift` | `@MainActor`. On open it reads the target window once (`FocusedWindowResolver`, only with Accessibility) and keeps a `CommandPalettePreviewContext` — arrow keys never call AX again (every AX read is in `readTargetWindow` / `previewContext`, called only from `show()`). The panel is a borderless `.nonactivatingPanel` that can become key: it takes typing while the front app stays in front, so the command target does not change and nothing has to be handed back. Untitled, so the Dock icon does not appear. The outline is a separate click-through panel ordered just below. Return closes first, then records the recent list and calls the app's `runCommand`; a second Return before closing is ignored. `registerHotkey(on:)` registers the palette shortcut after `HotkeyService.reload` |
| `CommandPaletteView.swift` | `CommandPaletteModel` (`@Observable`: query, results, selection) and the SwiftUI content: search field, rows (glyph, name, keycaps; selected row tinted with the accent glyph), footer hints and the opening shortcut. The search field is an AppKit `NSTextField`; ↑↓, Return and Esc come from the field editor's commands (`moveUp:`, `moveDown:`, `insertNewline:`, `cancelOperation:`) |

## For AI Agents
- Checked on a real Mac (macOS 27, signed Debug build) with a throwaway probe: English and Korean typing reach the panel while another app stays frontmost, and Return during Korean composition arrives once with the committed text. Re-check that if the panel type or the field changes.
- Settings search (`Commands/ShortcutListPolicy`) is separate on purpose; palette aliases do not change it.
- Execution goes through `AppDelegate.runCommand` so sound and notification feedback, the last-failure line and the cheat sheet follow the same path as a hotkey. Do not call `WindowCommandExecutor` from here. `runCommand` also dismisses an open palette, because a hotkey pressed while it is open moves the window and the outline would point at the old frame.
- Focus stays in the search field, so VoiceOver does not follow the selected row; the controller posts an announcement (name and shortcut) on each selection change.
- Testing: `make test` covers the policy (`Tests/CommandEngineTests+Palette.swift`). By hand with `make run`: open over another app, type, move and watch the outline, Return moves the window and typing goes back to that app, the recent command comes first next time, a second display, the Settings row (off, record, reset, Duplicate).

## Dependencies
- Internal: `Commands/CommandPlanPolicy` · `FixedSizePlacementPolicy`, `WindowAccess/FocusedWindowResolver` · `WorkAreaResolver` · `DisplayResolver` · `SnapStateStore` · `WindowFrameWriter.settableAnswer`, `Shared/CoordinateSpace`, `Preferences/PreferencesStore`, `UI/CommandGlyphView` · `KeycapsView`.
- External: AppKit, SwiftUI, Observation.

<!-- MANUAL: -->
