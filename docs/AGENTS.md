<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-01 | Updated: 2026-10-25 -->

# docs/

## Purpose
GitHub Pages source for the Azimuth website — a marketing landing page and a full user
manual. Plain static HTML/CSS/JS with **no build step**; published at
`https://ai-scream.ai/Azimuth/`. Both pages are **bilingual (EN/KO)** and share an
inline design-token stylesheet.

## Key Files
| File | Description |
|------|-------------|
| `index.html` | Marketing landing: hero (sky with clouds and an animated glass-window stage + Download/GitHub CTAs), feature cards, shortcuts, how-it-works, requirements/install, FAQ, and the funding/support block. Self-contained: inline `<style>` (design tokens, `prefers-color-scheme` dark mode), inline SVGs, JSON-LD `SoftwareApplication` structured data, OG/Twitter meta, `hreflang`, and a bottom `<script>` that labels the download button from `/releases/latest`. |
| `manual.html` | Complete reference: requirements, feature summary table, `#shortcuts` ("all 34 commands" + modifier-layer legend + Standard/Vim preset tables), command-behavior cards. Duplicates index.html's token CSS. No script. |
| `ko/` | **Generated** Korean pages (`index.html`, `manual.html`); see below. Never edit by hand. |
| `sitemap.xml` | The four pages with `hreflang` pairs, served at `/Azimuth/sitemap.xml`. No `lastmod`. |
| `404.html` | Not-found page for any missing path under `/Azimuth/` (so its links are absolute), same sky tokens, `noindex`. |
| `assets/` | Static images only: `favicon.png`, `apple-touch-icon.png`, `og-image.png` (all three generated from the app icon by `scripts/site/make-images.swift`), and demo screenshots `demo-snap.png` / `demo-throw.png`. |

## For AI Agents

### Working In This Directory
- **Bilingual (EN/KO) — edit THREE places per string.** Every translatable node carries a
  `data-en` attribute, a `data-ko` attribute, **and** the visible default (EN) text child. A
  copy change must update **all three**, or the languages drift.
- **Put `data-en`/`data-ko` on a text-only element.** The generator replaces the whole content, which would
  drop any child (it refuses instead): a button with an icon carries the attributes on an inner `<span>` (the
  download buttons, View on GitHub). The release fetch also writes its label into that span.
- **Korean pages are generated (#212).** `docs/ko/index.html` and `docs/ko/manual.html` come from the
  English sources by `scripts/site/build-ko.py`: an element's content becomes its `data-ko` (escaped text;
  `.install-note` as HTML), a `data-ko-<attr>` sets that attribute (`href`, `aria-label`, `alt`, `content`,
  `class`, `aria-current`, `lang`), and `assets/` paths gain `../`. Edit the English file, rerun the script,
  commit both. The script fails on a `data-en` without `data-ko`, and on `data-ko` over child elements.
- **Language links.** EN/KO in the top bar are links between the two pages (with `hreflang` and
  `aria-current`), not a JS toggle, and nothing redirects by browser language. Each page's `<head>` lists
  `hreflang` en, ko and x-default (the English page) and its own canonical; `sitemap.xml` repeats the pairs.
  The only script left is the release fetch on index, which labels the download button by `<html lang>`.
- **Keep counts in sync with code.** "N commands" / "N shortcuts" strings must match
  `WindowCommand.menuCommands` (currently **34**). In manual.html this is hardcoded in three
  spots (shortcuts heading + "all N unique key combinations" note, EN+KO each).
- **No hardcoded version.** The download CTA and JSON-LD `downloadUrl` point at
  `/releases/latest` — keep it that way so releases don't require doc edits. Canonical/OG URLs
  are absolute (`ai-scream.ai/Azimuth/...`); update only if the Pages URL changes.
- **Legacy build link is the one hardcoded version.** The macOS 10.13–12 legacy build never becomes
  `/releases/latest`, so index.html links its tag page (tag format `legacy-vX.Y.Z-N`) in the
  `#legacy` `.install-note` (a list, one item per older macOS, with `<a>`s inside; safe because that class is
  generated as HTML) and names it
  in the older-macOS FAQ; the hero's "Older Mac?" line is a separate `.dl-legacy` element so the
  `#dl-meta` rewrite cannot erase it. manual.html's macOS-version card has its own link as a separate
  `<p><a data-en data-ko>` (its text `<p>` is generated as plain text, which cannot hold an inline `<a>`).
  The `#download-legacy` button links the DMG itself (`releases/download/<tag>/Azimuth-X.Y.Z-legacy-N.dmg`);
  its label is an inner `<span data-en data-ko>` so the icon stays.
  The current tag is `legacy-v1.7.2-4`; bump it after each legacy release (README and SECURITY too).
  macOS 13 is pinned to `v1.7.7` (the last version for 13, never bumped): the same `#legacy` note, the
  `#download-macos13` button (`releases/download/v1.7.7/Azimuth-1.7.7.dmg`), its own link in the manual's
  macOS card, README and SECURITY.
  JSON-LD `SoftwareApplication` says "macOS 14+": it describes the `/releases/latest` download (2.x).
- **Funding links live in index.html's support block.** Ko-fi `https://ko-fi.com/pignuante`
  and GitHub Sponsors `https://github.com/sponsors/ai-screams` (see `.github/FUNDING.yml`).
- `assets/` holds only images — no `AGENTS.md` of its own.
- **Hero sky (#211).** One window is placed against the screen (`⌃⌥1` Left 1/3, `⌃⌥←` Left 1/2), shrunk
  against itself (`⌃⌥⇧↓`, `⌃⌥⇧←`) and undone (`⌃⌥⌫`) on an 18 s CSS loop. The keys and command names must
  match the Standard preset (`HotkeyPreset.swift`) and `displayName`s; change them together. All `sky-*`
  keyframes share the 18 s duration and their percentages line up by step, so retime them as a set. Moving
  elements never get `backdrop-filter` (it re-blurs every frame and stuttered on a phone). Reduce Motion
  sets `animation: none !important` on them, because the base rule only shortens durations and would make
  the infinite loops flicker. Light mode is a day sky, dark mode dusk (`--sky`, `--cloud-*` tokens).
  manual.html's header uses the same sky tokens, cloud defs and cloud CSS (copied, since the pages share no
  stylesheet) without the window demo; its clouds stay on the right because its text is left-aligned.
  Both pages use the app icon: an inline SVG (`#1E3A5F` tile, `#F2A541` north mark) in the top bar, and
  `assets/apple-touch-icon.png` at 32px in the footer (the 16px SVG lost the dial there).

### Testing Requirements
- No compiler/bundler: edit the English file, run `python3 scripts/site/build-ko.py`, and open both
  languages in a browser.
- **Publishing:** merging to `main` triggers the GitHub **"pages build and deployment"**
  workflow; the live site lags until that run completes — poll it to `completed`/`success`
  before verifying live content.
- When editing shared CSS tokens, mirror the change in **both** index.html and manual.html
  (the `<style>` block is duplicated).

### Common Patterns
- Section anchors (`#shortcuts`, `#how-it-works`, `#faq`, `#support`) are referenced by in-page
  nav and the footer — keep ids stable.
- shields.io badges / external funding pages return HTTP 403 to `curl` (bot wall); verify badge
  URLs return 200 in a browser, not via curl.

## Dependencies

### Internal
- Content mirrors app behavior in `Azimuth/Commands/WindowCommand.swift` (command list/count)
  and the default bindings in `Azimuth/Hotkeys/`. `README.md` covers the same feature set —
  keep the three in sync.
- Funding config: `.github/FUNDING.yml`.

### External
- GitHub Pages (hosting + the "pages build and deployment" workflow). No JS/CSS frameworks.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
