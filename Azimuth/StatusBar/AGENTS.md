<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-10-24 -->

# StatusBar

## Purpose
The menu-bar status item (#178). A left click opens a SwiftUI popover with the command grid; a right click or Control-click opens the `NSMenu` (permission state, settings, practice, updates, quit, and the DEBUG diagnostics and command submenu).

## Key Files
| File | Description |
|------|-------------|
| `StatusBarController.swift` | `@MainActor`, `NSMenuDelegate`. The status icon comes from `StatusBarIcon` (template image; a warning badge is overlaid when permission is needed). Left and right clicks arrive as the button's action (`sendAction(on: [.leftMouseUp, .rightMouseUp])`); `StatusClickPolicy` picks popover or menu. The menu is attached only while it is open (`menuDidClose` detaches it), because an attached `menu` swallows the button action. The menu holds: permission state / open Accessibility settings / the last command failure reason (an informational row fed by the `lastFailureText` closure that AppDelegate injects, hidden when there is no failure) / Check for Updates… / Open Settings (`⌘,`) / Practice Shortcuts… (`onPracticeShortcuts`, opens the #176 practice window) / Quit (`⌘q`). Under DEBUG it also offers focused-window identification, a submenu of all 34 commands (`WindowCommand.menuCommands`) and "Design Gallery (Debug)", which opens `DesignGallery/DesignGalleryWindowController` |
| `StatusBarIcon.swift` | #179 menu bar icon (design M2) drawn in code at 18pt: a short arc with a north tick over a window whose left half is filled. `needsPermission` overlays a warning triangle at the bottom right, cleared out of the drawing underneath. Template image, so the system tints it. The first-run guide shows the same image next to "Click the menu bar icon" |
| `StatusPopoverController.swift` | Owns the `NSPopover` (transient) anchored to the status button. Activates the app before showing (transient dismissal and keyboard input need it). `popoverShouldClose` ignores a mouse-down on the status button so a second click closes instead of reopening. It sizes the popover itself (`sizingOptions = []`, `sizeThatFits` at 340pt width before showing and after the failure row changes): automatic sizing pushed the popover above the menu bar, and `view.fittingSize` before attaching clipped it. On close it hands activation back to the command target app (`FrontmostAppTracker.targetApplication`) when Azimuth was not active before opening and the popover was not closed by a button that opened a window (`PopoverActivationPolicy`), since an `NSMenu` never activated the app. A Settings window left open behind does not count: checking for visible windows kept Azimuth in front and swallowed typing (seen on a real Mac) |
| `StatusPopoverModel.swift` | `@Observable` state (permission, last failure, applied command, keyboard cursor, `canCheckForUpdates`) and `StatusPopoverDependencies`, the closures the popover asks the app through. `refresh()` runs on every open. Footer actions run before the popover closes, so a Settings window is already up when the close handler checks for windows |
| `StatusPopoverView.swift` | The popover content: permission header (with "Open Accessibility Settings…" when missing), the 34 commands as glyph tiles in groups of 8 columns (dimmed and disabled without permission), the applied command's name and keycaps, the last failure, and Open Settings… ⌘, / Check for Updates… / Quit Azimuth ⌘Q. Arrow keys move a cursor, Return or Space applies, Escape closes. Hovering a footer row highlights it like a menu item; hovering a tile shades it. The grid is a non-lazy `Grid` built from `PopoverGridLayout` rows, so its height is known before showing. No glass yet (#179) |
| `StatusPopoverPolicy.swift` | Pure, in the harness: `StatusClickPolicy` (click → popover or menu), `PopoverActivationPolicy` (hand activation back on close) and `PopoverGridLayout` (rows per group, arrow-key moves, `commands` is the grid order — group by group, not `menuCommands` order) |

## For AI Agents

### Working In This Directory
- Permission refreshes (cache invalidated) every time the menu or the popover opens, and on app activation through `refreshPermissionState`. The last-failure row refreshes in `menuWillOpen`; the popover reads it in `refresh()` and again after each tile.
- Popover tiles run commands through `runCommand`, which `AppDelegate` wires to the same `runCommand` the hotkeys use, so beeps, the last-failure reason and notifications match. Keycaps come from the same `boundShortcut` as the practice window. Do not call `WindowCommandExecutor` from the popover.
- Keep this file's class body under the `type_body_length` limit: the click routing and popover construction live in an extension.
- Wrap DEBUG-only diagnostics in `#if DEBUG` so they never reach the RELEASE menu.
- The menu-bar icon is an SF Symbol (a template image), so it needs no asset. With a crowded menu bar and multiple displays, macOS may hide the item — that is outside the app's control.

### Testing Requirements
- Use `make run` to confirm the menu-bar item appears, the permission color changes, and the DEBUG command submenu works.
- Popover behaviour that only a person can check: second click closes, Escape returns focus to the previous app, arrow keys and Return, VoiceOver labels on tiles, right-click menu, hiding the icon closes the popover.

### Common Patterns
- Commands run through `Commands/WindowCommandExecutor.run`, the same path as hotkeys (one path only). On failure: beep and log.

## Dependencies

### Internal
- `Permissions/AccessibilityPermissionService`, `Commands/WindowCommandExecutor` · `WindowCommand`, `WindowAccess/FrontmostAppTracker` · `FocusedWindowResolver` · `WindowUndoStore` · `SnapStateStore`, `Shared/Log`.

### External
- Cocoa (NSStatusBar / NSMenu / NSPopover), SwiftUI, Observation, os.

<!-- MANUAL: -->
