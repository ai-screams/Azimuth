<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-10-22 | Updated: 2026-10-24 -->

# UI

## Purpose
Shared SwiftUI parts for the 2.0 screens (#181). The Settings window, the menu bar popover, the cheat sheet, the command palette and the first-run guide are to draw commands through these views (each screen adopts them in its own issue).

## Key Files
| File | Description |
|------|-------------|
| `CommandGlyphView.swift` | Draws `WindowCommand.glyph` (`Commands/CommandGlyph`) with `Canvas`; it holds no coordinates of its own. Color rule: text color in lists, the system accent only when `emphasized` (a selected or active row). `scale` enlarges the shape but keeps the 1× line width and dash |
| `KeycapsView.swift` | One keycap per modifier and key from `HotkeyShortcut.keycapLabels`. A nil shortcut shows "—" (decided by the value, not a mode). Modes: normal, recording ("Type shortcut…" with an accent border), disabled (dimmed). `Keycap` (one cap) is shared with the cheat sheet header |
| `AdaptiveShapes.swift` | #179. The one place for macOS 26 `#available` look branches. `AdaptiveShapes.inner(outer:inset:minimum:)` gives an inner rounded rect whose radius is the outer radius minus the inset (`Shared/ConcentricRadius`), used by palette rows and cheat-sheet keys. `selectionGlass(_:in:)` marks the selected element: interactive glass tinted with the accent on 26+, accent fill and border on 14–15 (the popover's applied tile). SwiftUI `ConcentricRectangle` is not used: inside a list it rounded rows far from the corners to the outer radius too (offscreen render) |
| `CheatSheetView.swift` | #182 keyboard map for one `Hotkeys/CheatSheetLayer`: header (held modifiers, layer title, "Release to close"), the rows from `CheatSheetKeyboard` with each bound key showing glyph and name and the rest dimmed, and an "Other keys" strip for bindings off the map. Key widths come from `CheatSheetKeyboard.widths`, 44×60 keys |

## For AI Agents
- Geometry and labels are pure values tested in the harness; these views only draw them. Change a shape in `Commands/CommandGlyph.swift`, not here.
- Use only APIs available on the deployment target and in the CI SDK (Xcode 26.x).
- Check visual changes in the DEBUG design gallery (`DesignGallery/`) with `make run`, in light and dark.

<!-- MANUAL: -->
