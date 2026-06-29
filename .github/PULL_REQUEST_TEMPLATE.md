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
- [ ] Built locally — permission-affecting changes tested with `make run` (signed), not ad-hoc `make build`
- [ ] Docs updated if behavior/commands/shortcuts/CI changed (README, `docs/`, AGENTS.md)
- [ ] No secrets committed; `.docs/` not staged (it's gitignored)
- [ ] Version bump handled separately (release PRs only)

## Notes / risk

<!-- Edge cases, multi-monitor/fixed-size-app considerations, follow-ups, anything reviewers should scrutinize. -->
