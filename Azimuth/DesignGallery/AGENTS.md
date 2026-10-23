<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-10-22 | Updated: 2026-10-24 -->

# DesignGallery

## Purpose
DEBUG-only window for checking the 2.0 redesign on a real macOS before each screen is implemented. Opened from the status menu's "Design Gallery (Debug)". Every file is wrapped in `#if DEBUG`, so nothing here reaches a Release build.

## Key Files
| File | Description |
|------|-------------|
| `DesignGalleryWindowController.swift` | Entry point: hosts the page in an `NSWindow`, opened from the status menu |
| `DesignGalleryView.swift` | The gallery page: glyph catalog at 1× and 2×, keycap states, then the samples. All sample state is local `@State`; nothing writes preferences |
| `HotkeyPreset+Gallery.swift` | `HotkeyPreset.galleryShortcut(for:)` for sample keycaps. Glyphs and keycaps come from the real parts in `UI/` |

## For AI Agents
- Use only APIs available in the CI SDK (Xcode 26.x). Never `#available(macOS 27`.
- When a part graduates into its issue (#175, #178, …), move it out of `#if DEBUG` into its real directory, add pure logic to `scripts/harness-sources.sh` with tests, and delete the gallery copy. #181's glyphs and keycaps (`Commands/CommandGlyph`, `UI/`) #175's General pane and Shortcuts rows (`Settings/GeneralSettingsView`, `Settings/ShortcutsSettingsView`) #178's popover grid (`StatusBar/StatusPopoverView`) and #182's cheat sheet (`UI/CheatSheetView`) already graduated. Glass on the popover tiles waits for #179; tiles keep a fixed 6pt radius because `ConcentricRectangle` without a container shape draws square corners (seen in round 1).
- Verify by `make run` and looking at the window; `ImageRenderer` output is not a substitute (offscreen rendering differs for `Form` and glass).

<!-- MANUAL: -->
