# Contributing to Azimuth

Thanks for your interest in improving Azimuth! This guide covers the essentials. For deeper
architecture and directory-level conventions, see [`AGENTS.md`](AGENTS.md) and the per-directory
`AGENTS.md` files.

## Ground rules

- **Never bypass macOS permissions or security.** Accessibility is requested through the official
  API (`AXIsProcessTrustedWithOptions`) and granted by the user in System Settings — the legitimate
  way, always. No SIP disabling, no TCC tampering, no undocumented workarounds. Apple's own
  `tccutil reset` is fine.
- **Predictability over clever inference.** Every command does exactly one well-defined thing and
  effects compose. Prefer composing existing commands over adding a "smart" special case.

## Prerequisites

- macOS **26.3 (Tahoe)** or later, with Xcode.
- Command-line tools used by the hooks and CI:

  ```bash
  brew install swiftlint swiftformat gitleaks
  ```

## Getting started

```bash
git clone https://github.com/ai-screams/Azimuth
cd Azimuth
make install-hooks   # pre-commit: SwiftFormat --lint + SwiftLint --strict
make run             # build a SIGNED build and launch it
```

Use **`make run`** for anything that needs the Accessibility permission — it signs with a stable
Apple Development identity so your grant survives rebuilds. **`make build`** is ad-hoc signed
(cdhash changes every build, which resets TCC) and is for **compile/CI checks only**.

## Make targets

| Target | Purpose |
|--------|---------|
| `make run` | Build a signed app and launch it (daily use / permission testing) |
| `make build` | Compile-only verification (ad-hoc; CI/compile checks) |
| `make test` | Run the pure-logic command-engine tests (swiftc); prints `PASS — all N checks` |
| `make lint` | SwiftLint (strict) |
| `make format` | SwiftFormat |
| `make secrets` | gitleaks secret scan |

## Before you open a PR

Run the same checks CI runs:

```bash
make build && make lint && make test
```

- Add or update **pure-logic tests** in `Tests/` for any change to command/geometry behavior
  (they compile AppKit-free via swiftc, so they stay fast and deterministic).
- If you touch launch / `Info.plist` / target settings, verify the **window actually appears** —
  not just that the process survives.

## Coding conventions

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: types are `@MainActor` by default. Mark pure,
  thread-agnostic logic explicitly `nonisolated`, and keep it in the AppKit-free layer so it's
  testable.
- Window geometry is handled in **AX coordinates** (top-left origin, Y down); convert to/from
  Cocoa work areas via `Shared/CoordinateSpace`.
- SwiftLint strict: no force-unwrap / force-cast (narrow, commented exceptions only), 120-column
  lines, function/type body length limits.
- Keep comments matching the surrounding density and idiom.

## Commit & PR style

- Use **Conventional Commits**: `feat(scope): …`, `fix(scope): …`, `docs(…)`, `refactor(…)`,
  `chore(…)`.
- Branch off `main`; keep PRs focused. Fill in the pull request template.
- CI (lint + macOS `xcodebuild` build + gitleaks secret scan) must be green before merge.

## Reporting bugs & security issues

- **Bugs / feature requests:** open a [GitHub issue](https://github.com/ai-screams/Azimuth/issues).
- **Security vulnerabilities:** do **not** file a public issue — follow [`SECURITY.md`](SECURITY.md).

By contributing, you agree that your contributions are licensed under the project's
[Apache-2.0 License](LICENSE).
