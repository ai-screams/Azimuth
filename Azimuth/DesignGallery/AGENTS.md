<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-10-22 | Updated: 2026-10-22 -->

# DesignGallery

## Purpose
DEBUG-only window for checking the 2.0 redesign on a real macOS before each screen is implemented. Opened from the status menu's "Design Gallery (Debug)". Every file is wrapped in `#if DEBUG`, so nothing here reaches a Release build.

## Key Files
| File | Description |
|------|-------------|
| `GalleryGlyphGeometry.swift` | `nonisolated` geometry of each command glyph (#181, Outline) in a 28×20 box: screen, second screen, target region, dashed ghost, arrow strokes. An exhaustive `switch` over `WindowCommand`, so a new command stops the build here |
| `GalleryComponents.swift` | `GalleryCommandGlyph` (text color in lists, accent only when selected), `GalleryKeycaps` (one cap per modifier and key, built from the modifier mask and key label, never by splitting the display string), no `ConcentricRectangle` yet: without a container shape it draws square corners (seen in round 1) |
| `DesignGalleryView.swift` | The gallery page: glyph catalog at 1× and 2×, keycap states |
| `DesignGallerySamples.swift` | Screen samples in grouped `Form`s: Shortcuts rows, General pane (layout A), popover grid P1 with optional Liquid Glass on 26+. All state is local `@State`; nothing writes preferences |
| `DesignGalleryWindowController.swift` | Hosts the page in an `NSWindow` |

## For AI Agents
- Use only APIs available in the CI SDK (Xcode 26.x). Never `#available(macOS 27`.
- When a part graduates into its issue (#181, #175, #178), move it out of `#if DEBUG` into its real directory, add pure logic to `scripts/harness-sources.sh` with tests, and delete the gallery copy.
- Verify by `make run` and looking at the window; `ImageRenderer` output is not a substitute (offscreen rendering differs for `Form` and glass).

<!-- MANUAL: -->
