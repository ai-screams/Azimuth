<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-19 | Updated: 2026-09-26 -->

# Settings

## Purpose
The settings window, split into three toolbar tabs (**General / Shortcuts / Advanced**). Stacking every card in one vertical scroll made the window open taller than 1,100pt because of the 34 shortcuts (#113); the tabs fixed that. The window controller only creates, shows and places the window; the tab container owns the panes and negotiates window height; each pane owns its own cards. The General pane itself lives at `Azimuth/GeneralPaneViewController.swift` (a historical location).

## Key Files
| File | Description |
|------|-------------|
| `SettingsWindowController.swift` | `@MainActor`. Takes its dependencies through the initializer, builds the three panes and installs `SettingsTabController` as the window's `contentViewController`. `show()` centers the window on the screen holding the mouse, then displays it. The controller is cached (one settings window). The first `setContentSize` inside `applyResizeLimits` is a **required** call that fixes the pane width (see the comment there) |
| `SettingsTabController.swift` | `NSTabViewController` (toolbar tabs; segmented below macOS 11). Defines the `SettingsPane` protocol (`naturalContentHeight()`, `paneTitle`, `paneSymbolName`, `initialFocusView`). **Legacy branch:** `applyFixedWindowSize()` measures General’s natural height once and pins the window (`contentMinSize = contentMaxSize`); tab switches and group expansion never resize it. Each tab item’s `initialFirstResponder` comes from `initialFocusView` |
| `SettingsPaneScaffold.swift` | The shared pane skeleton: a vertical scroll view + a `FlippedView` document view + a content stack + an inset of 24. All three panes use it (this is what removed the triple duplication). The returned document view's height is the natural height |
| `ShortcutsPaneViewController.swift` | The Shortcuts tab. Hosts `ShortcutsSectionView` inside a card. `viewWillAppear` collapses every group (`collapseAllGroups`) and refreshes the rows; the window stays at its fixed size and the pane scrolls. `initialFocusView` is the search field |
| `AdvancedPaneViewController.swift` | The Advanced tab. The "Wait for unresponsive apps" resolve-timeout popup (`ResolveTimeoutChoice`) plus its explanation. Changes are handed to the app through the `setResolveTimeout` closure, so this pane never touches `WindowAccess` directly |
| `ShortcutsSectionView.swift` / `+Layout.swift` | The preset segmented control + search + 34 command rows (recorder, Reset, the modified dot, conflict/occupied badges). A group header carries two controls with different meanings — **a disclosure triangle (collapse; display only)** and **a checkbox (hotkey registration on/off for that group)** — distinguished by their accessibility labels. Collapse state is not persisted. Row, header and separator visibility is decided by `Commands/ShortcutListPolicy` (pure, tested) and the view only applies it; while searching, matching groups expand automatically. Row appearance (recorder string, the checkbox's two axes, Reset, dimming, the modified dot, the badge) is decided by `Commands/ShortcutRowPolicy` (pure) and again the view only pushes it into widgets. The four per-group views (checkbox, triangle, header, separator) are bundled as `GroupViews` and held in a single `[CommandGroup: GroupViews]` — the token is used only when talking to the store |
| `SettingsCard.swift` / `BadgeLabel.swift` / `ShortcutRecorderButton.swift` | The card container (symbol + title + body), the status badge, and the shortcut recorder button (which calls back to suspend global hotkeys while recording) |

### Legacy branch notes
- **Fixed window size.** `SettingsTabController` measures General's natural height once and pins `contentMinSize = contentMaxSize` to it; longer panes scroll inside the scaffold. Below 11 the tabs use `.segmentedControlOnTop` (toolbar tabs leave an empty icon slot without SF Symbols).
- **Shortcuts pane performance (#137).** Rows added with `addArrangedSubview` stay in the hierarchy while `isHidden` (`detachesHiddenViews` does not apply on this path): ~690 views with every group collapsed, re-laid-out and key-looped on every tab switch. `ShortcutsSectionView.pruneHiddenSlots()` detaches hidden slots and re-inserts newly visible ones in order (delta), restoring the width constraint to `rowsStack` and the separator's custom spacing that `removeFromSuperview` drops; focus inside a slot being removed moves to the search field first (a recording recorder cancels in `resignFirstResponder`). `SettingsPane.initialFocusView` (Shortcuts: the search field) feeds `NSTabViewItem.initialFirstResponder`; the window uses `autorecalculatesKeyViewLoop`.

## For AI Agents

### Working In This Directory
- For a new setting, **pick the tab first**: General for everyday users, Shortcuts for anything about key bindings, Advanced for things nobody should need to change (the structure itself says "you don't have to come here"). A pane takes only the dependencies it needs through its initializer, so the signature shows what it depends on.
- A pane's `loadView` width must come from `SettingsTabController.windowWidth`. If the width is wrong, the natural height is computed against the wrong width — and the harness cannot catch that.
- Window height is **clamped to the screen's visibleFrame by AppKit itself** (`NSWindow.constrainFrameRect`). Do not add a manual clamp; overflowing content is handled by the pane's scroll view.
- To change how search and collapsing interact, edit `Commands/ShortcutListPolicy` and its tests, not the view.
- Window placement follows the screen containing `NSEvent.mouseLocation`. Preserve that behavior (multi-monitor regression).

### Testing Requirements
- `make lint` + `make test` (`ShortcutListPolicy`, `ShortcutRowPolicy`) + compile. Human check (legacy: an x86_64 10.13 build on real hardware, since `make run` cannot build this branch): the window keeps General’s height on all three tabs and never resizes; the Shortcuts tab opens with groups collapsed and scrolls inside the window; expanding a group, searching and clearing keep rows at full width; Tab moves only through visible controls.

### Common Patterns
- Dependency injection: constructor injection instead of singletons. Notifications back to the app go through closures (`onHotkeysChanged`, `setHotkeysSuspended`, `setResolveTimeout`, `checkForUpdates`), with `[weak self]` to avoid retain cycles.
- A pane's `naturalContentHeight()` **delegates in one line to `SettingsPaneScaffold.naturalContentHeight(of:in:)`.** The three panes had copied the same nine lines, so they were merged — a new pane should delegate, not copy. On measurement failure (a nil `documentView`) the scaffold calls `assertionFailure` and returns `minWindowHeight`, because letting 0 through would make a 400pt window look like a success.
- The window controller's `applyResizeLimits` sets the width first (the pane's natural height depends on it), then calls `tabController.applyFixedWindowSize()` — the only place the fixed size is decided (legacy branch).

## Dependencies

### Internal
- `Azimuth/GeneralPaneViewController` (the General pane), `Commands/ShortcutListPolicy`, `Commands/ShortcutRowPolicy`, `Preferences/PreferencesStore`, `Launch/LaunchAtLoginService`, `Hotkeys/BindingResolver` · `HotkeyPreset`, `Shared/AXMessagingTimeout` (`ResolveTimeoutChoice`), `FlippedView`.

### External
- Cocoa (NSWindowController / NSWindow / NSScreen / NSTabViewController / NSStackView).

<!-- MANUAL: -->
