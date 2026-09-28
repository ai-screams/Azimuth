<!-- Keep PRs focused and atomic. Delete sections that don't apply. -->

## Summary

<!-- What does this change and why? Link issues with #123 if relevant. -->

## Type

- [ ] feat — user-facing feature
- [ ] fix — bug fix
- [ ] refactor — no behavior change
- [ ] ci / chore — pipeline, tooling, release
- [ ] docs

## Checklist

- [ ] `make lint` clean (SwiftFormat + SwiftLint `--strict`)
- [ ] `make test` passes; `make coverage` ≥ 90% (pure-logic lines) if logic changed
- [ ] Built locally — permission-affecting changes tested with a signed build (`make run` on `main`, `make legacy-app`
      on `legacy/10.13`), not ad-hoc `make build`
- [ ] Docs updated if behavior/commands/shortcuts/CI changed (README, `docs/`, AGENTS.md)
- [ ] No secrets committed; `.docs/` not staged (it's gitignored)
- [ ] Version bump handled separately (release PRs only)

## Legacy build (macOS 10.13–12)

<!-- Tick what applies. The legacy build takes critical and security fixes only; see LEGACY.md. -->

- [ ] Not needed — a feature, polish, or main-only change, or 10.13–12 users cannot hit it
- [ ] Needed — critical or security fix; legacy PR: #
- [ ] This PR targets `legacy/10.13` (port of #)
- [ ] Touches a file in `scripts/shared-with-legacy.txt` — matching PR on the other branch: #

## Notes / risk

<!-- Edge cases, multi-monitor/fixed-size-app considerations, follow-ups, anything reviewers should scrutinize. -->
