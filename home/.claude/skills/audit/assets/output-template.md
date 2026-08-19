# Audit — <project or scope>

Skeleton for the findings doc. Write it to `.planning/audit[-<scope>]/status.md` and follow the `planning-docs` skill grammar (this is a planning doc, not a bespoke report). Replace the angle-bracket placeholders; delete guidance comments.

---

**Status:** Findings ready for triage — <N> findings (<H> high / <M> med / <L> low). No code changed yet.

## Scope

- **Audited:** <what was covered>
- **Excluded:** <vendored/generated/boilerplate, etc.>
- **Deprioritized:** <on medium/large repos, what was not deeply examined> — say "go deeper" to audit these next.

## Low-hanging fruit

High-impact + quick wins, pulled out for convenience (also listed under their priority below).

- [ ] <finding title> — `path/to/file.ts:42` #priority/high #effort/quick #category/<cat>
    - Why: <what's wrong / why it matters>
    - Suggested change: <concrete fix>

## High priority

- [ ] <finding title> — `path/to/file.ts:88` #priority/high #effort/moderate #category/<cat>
    - Why: <…>
    - Suggested change: <…>

## Medium priority

- [ ] <finding title> — `path/…` #priority/med #effort/<…> #category/<cat>
    - Why: <…>
    - Suggested change: <…>

## Low priority

- [ ] <finding title> — `path/…` #priority/low #effort/<…> #category/<cat>
    - Why: <…>
    - Suggested change: <…>

<!-- Use `- [?]` for a finding that needs a decision from the user (they answer in a nested `- [<]`).
     Use `- [i]` for an observation that needs no action.
     "Cross-cutting" is a valid location when a finding spans many files. -->
