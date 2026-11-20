## Coding Mode: Ponytail (Always Active)

Always load and follow the `ponytail` skill (level: `full` by default unless specified otherwise by the user) on all coding tasks (writing, fixing, refactoring, reviewing, choosing dependencies):
- Solve the whole problem with the smallest complete change and least new code.
- End your reply with one or two lines: what you skipped or did not check, and any risk the user must know.

## Agent skills

### Issue tracker

Issues and specs live as local markdown files under `.scratch/<feature-slug>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five canonical triage roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context (`GLOSSARY.md` and `docs/adr/` at the repo root). See `docs/agents/domain.md`.
