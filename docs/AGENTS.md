<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-01 | Updated: 2026-07-01 -->

# docs/

## Purpose
GitHub Pages source for the Azimuth website — a marketing landing page and a full user
manual. Plain static HTML/CSS/JS with **no build step**; published at
`https://ai-scream.ai/Azimuth/`. Both pages are **bilingual (EN/KO)** and share an
inline design-token stylesheet.

## Key Files
| File | Description |
|------|-------------|
| `index.html` | Marketing landing: hero (CSS desktop mockup + Download/GitHub CTAs), feature cards, shortcuts, how-it-works, requirements/install, FAQ, and the funding/support block. Self-contained: inline `<style>` (design tokens, `prefers-color-scheme` dark mode), inline SVGs, JSON-LD `SoftwareApplication` structured data, OG/Twitter meta, and a bottom language-toggle `<script>`. |
| `manual.html` | Complete reference: requirements, feature summary table, `#shortcuts` ("all 34 commands" + modifier-layer legend + Standard/Vim preset tables), command-behavior cards, roadmap. Duplicates index.html's token CSS and has its own copy of the language-toggle script. |
| `assets/` | Static images only: `favicon.png`, `apple-touch-icon.png`, `og-image.png`, and demo screenshots `demo-snap.png` / `demo-throw.png`. |

## For AI Agents

### Working In This Directory
- **Bilingual (EN/KO) — edit THREE places per string.** Every translatable node carries a
  `data-en` attribute, a `data-ko` attribute, **and** the visible default (EN) text child. A
  copy change must update **all three**, or the languages drift. (index.html ≈126 `data-en`
  nodes; manual.html ≈164.)
- **Language toggle.** A bottom-of-page inline IIFE `<script>` (one per page) swaps
  `textContent` for all `[data-en],[data-ko]` nodes; `localStorage` key `azimuth-lang`, default
  `en`. Special case: `.install-note` uses `innerHTML` (embeds `<strong>`). index.html also
  rewrites the download button + `#dl-meta` after resolving `/releases/latest`, so any
  dynamically injected string must set `data-en`/`data-ko` too.
- **Keep counts in sync with code.** "N commands" / "N shortcuts" strings must match
  `WindowCommand.menuCommands` (currently **34**). In manual.html this is hardcoded in three
  spots (shortcuts heading + "all N unique key combinations" note, EN+KO each).
- **No hardcoded version.** The download CTA and JSON-LD `downloadUrl` point at
  `/releases/latest` — keep it that way so releases don't require doc edits. Canonical/OG URLs
  are absolute (`ai-scream.ai/Azimuth/...`); update only if the Pages URL changes.
- **Legacy build link is the one hardcoded version.** The macOS 10.13–12 legacy build never becomes
  `/releases/latest`, so index.html links its tag page (tag format `legacy-vX.Y.Z-N`) in the
  `#legacy` `.install-note` (an `<a>` inside, safe because that class swaps `innerHTML`) and names it
  in the older-macOS FAQ; the hero's "Older Mac?" line is a separate `.dl-legacy` element so the
  `#dl-meta` rewrite cannot erase it. manual.html's macOS-version card has its own link as a separate
  `<p><a data-en data-ko>` (its text `<p>` swaps `textContent`, which would erase an inline `<a>`).
  The `#download-legacy` button links the DMG itself (`releases/download/<tag>/Azimuth-X.Y.Z-legacy-N.dmg`);
  its label is an inner `<span data-en data-ko>` so the toggle keeps the icon.
  The current tag is `legacy-v1.7.2-3`; bump it after each legacy release (README and SECURITY too).
  JSON-LD `SoftwareApplication` stays "macOS 13+" on purpose: it describes the `/releases/latest` download.
- **Funding links live in index.html's support block.** Ko-fi `https://ko-fi.com/pignuante`
  and GitHub Sponsors `https://github.com/sponsors/ai-screams` (see `.github/FUNDING.yml`).
- `assets/` holds only images — no `AGENTS.md` of its own.

### Testing Requirements
- No compiler/bundler: edit and open the file in a browser to verify. Toggle EN⇄KO and check
  both languages render.
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
