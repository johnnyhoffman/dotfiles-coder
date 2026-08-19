# Audit finding categories

The checklist for an audit. Each category lists what to look for and the `#category/*` tag to apply. **Precision gate applies to all:** only record a finding if acting on it would genuinely improve the codebase — skip nits and likely false positives.

Contents: DRY · elegance · outdated-code · docs · inconsistency · smell · dead-code · bug.

## `#category/dry` — repetition

- Duplicated logic, copy-pasted blocks, parallel structures that drift out of sync.
- **Gate (important):** only flag if a DRY refactor would actually improve quality — not every repetition is worth abstracting. Over-abstraction is itself a smell; prefer leaving incidental duplication alone.

## `#category/elegance` — elegance / simplification / robustness

- Convoluted control flow, needless indirection, over-engineering, or fragile constructs that could be simpler, clearer, or more robust.
- Solutions that could be reworked more cleanly given what's known now.

## `#category/outdated` — outdated code

- Stale workarounds, dead feature flags, commented-out blocks, leftovers from a prior approach/migration/experiment that no longer apply.
- Patterns left behind by a since-completed migration or a moved/renamed module.

## `#category/stale-doc` — documentation

- **Outdated docs:** README / `CLAUDE.md` / `SOUL.md` / inline comments that no longer match the implementation.
- **Missing docs:** non-obvious behavior, public APIs, or conventions with no documentation.
- **Drift:** doc says X, code does Y. Docs are explicitly in scope; updates are valid findings.

## `#category/inconsistency` — inconsistencies / incongruencies

- Divergent naming, structure, error-handling, or patterns for the same kind of thing.
- Cross-module / cross-project inconsistencies that could be standardized.

## `#category/smell` — antipatterns / code smells / clutter

- Recognized antipatterns, code smells, magic values, dead config, clutter, and accumulated cruft.
- Things that "work" but signal deeper design trouble.

## `#category/dead-code` — dead / unused code

- Unreferenced functions, exports, files, deps, or assets.
- **Verify before flagging:** confirm something is truly unused (check tests, dynamic/string references, build config, re-exports) — apparent dead code is often used indirectly.

## `#category/bug` — correctness

- Latent bugs, edge cases, race conditions, incorrect error handling, off-by-one, mishandled nulls.
- Emphasize this category when auditing recent changes / a migration diff.
