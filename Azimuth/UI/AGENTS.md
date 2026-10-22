<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-10-22 | Updated: 2026-10-22 -->

# UI

## Purpose
Shared SwiftUI parts for the 2.0 screens (#181). The Settings window, the menu bar popover, the cheat sheet, the command palette and the first-run guide are to draw commands through these views (each screen adopts them in its own issue).

## Key Files
| File | Description |
|------|-------------|
| `CommandGlyphView.swift` | Draws `WindowCommand.glyph` (`Commands/CommandGlyph`) with `Canvas`; it holds no coordinates of its own. Color rule: text color in lists, the system accent only when `emphasized` (a selected or active row). `scale` enlarges the shape but keeps the 1× line width and dash |
| `KeycapsView.swift` | One keycap per modifier and key from `HotkeyShortcut.keycapLabels`. A nil shortcut shows "—" (decided by the value, not a mode). Modes: normal, recording ("Type shortcut…" with an accent border), disabled (dimmed) |

## For AI Agents
- Geometry and labels are pure values tested in the harness; these views only draw them. Change a shape in `Commands/CommandGlyph.swift`, not here.
- Use only APIs available on the deployment target and in the CI SDK (Xcode 26.x).
- Check visual changes in the DEBUG design gallery (`DesignGallery/`) with `make run`, in light and dark.

<!-- MANUAL: -->
