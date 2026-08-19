# Audit-doc lifecycle (fix-mode)

Read this only when the user has reviewed the findings and asked to start fixing. The findings doc is a living planning doc — follow the `planning-docs` skill grammar throughout.

## Triage states

The user marks each finding before/while fixing:

- `- [x]` — accepted, do it.
- `- [-]` — dismissed, leave it.
- `- [?]` — needs a decision from you; answer in a nested `- [<]` and wait.

Work only accepted (`[x]`) items unless told otherwise. Never fix a dismissed or undecided item.

## Resolving items

1. **One at a time.** Take the next accepted finding; make the change.
2. **Verify** it's correct and didn't break anything (tests/typecheck/lint as appropriate).
3. **Commit per item** — one focused commit per finding (Conventional Commits style), so each is independently reviewable/revertable.
4. **Update the doc:** mark the finding done and prune it — either strike/remove resolved items or move them to a "Resolved this pass" section. Keep the doc reflecting only what's left.
5. Repeat.

## Re-pass for misses

After resolving a batch, take another pass over the same scope:

- Look for anything missed the first time, and for new issues the changes themselves introduced.
- Add any new findings (tagged as usual). If the re-pass is clean, say so.

## Pruning / closing out

- When all accepted items are resolved, summarize what was done and confirm whether the doc should be archived or kept for the next round.
- Don't leave stale resolved items cluttering the doc.
