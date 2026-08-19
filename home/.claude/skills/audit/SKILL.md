---
name: audit
description: Broad codebase health/quality sweep — finds code smells, DRY violations, antipatterns, dead/unused code, outdated or missing docs, inconsistencies, and elegance/simplification opportunities, then writes a triaged findings doc. Use when the user wants to "audit" a project, codebase, or subsystem, or asks for a general quality/cleanup pass. NOT for reviewing a specific diff/PR for correctness — that is /code-review.
argument-hint: [optional scope or instructions, e.g. "the auth module" or "changes in the last 3 commits"]
allowed-tools: Read, Grep, Glob, Bash(git status*), Bash(git log *), Bash(git diff *), Bash(git show *), Bash(git ls-files *), Bash(rg *), Bash(cloc *), Bash(tokei *)
---

# /audit — codebase quality sweep

Sweep a project (or a scoped part of it) for quality and health issues, then write a **triaged findings doc** the user works through. Findings-only by default: surface and prioritize, **do not change code** until asked.

`$ARGUMENTS` is free-form, `/compact`-style — it's scope *and/or* general direction. Empty = whole project.

- `/audit` → whole project.
- `/audit the auth module` / `/audit changes in the last 3 commits` → scoped.
- `/audit ignore tests and prioritize the public API` → general steering, not just scope.

## Relationship to /code-review

Standalone — no dependency. `/code-review` reviews the **current diff/branch** for correctness bugs + small cleanups (and can post PR comments / auto-fix). `/audit` sweeps a **whole project or subsystem** for broad health and writes a triage doc. If a request is "review my PR / these changes for bugs," prefer `/code-review`.

## Workflow

Work through these phases. The checklist read in step 2 is mandatory every run; the lifecycle read in step 7 only when fixing.

1. **Scope.** Interpret `$ARGUMENTS` (default: whole project). Use `git ls-files` to enumerate tracked files; **exclude vendored/generated/boilerplate** (deps, lockfiles, build output, code copied from upstream). State the resolved scope and exclusions before going further.
    - **Adaptive scoping by size** (small <~20 files: exhaustive · medium: prioritized · large >~200: critical-path / high-signal first). On medium/large, say up front what you're deprioritizing, and after the pass **offer an explicit go-deeper follow-up** on the deprioritized areas.

2. **Load the checklist.** Read `reference/categories.md` now — it defines the finding categories and their `#category/*` tags. (Mandatory; don't skip.)

3. **Survey.** Map the structure and read the in-scope code. Note conventions in `README` / `CLAUDE.md` / `SOUL.md` — **docs are in scope** (outdated, missing, or drifted-from-implementation docs are valid findings).

4. **Filter — precision over recall.** Keep a candidate finding only if acting on it would *genuinely* improve quality (the user's "only if it actually improves things" gate). Drop low-value nits and likely false positives. A short, high-signal list beats an exhaustive dump.

5. **Write the findings doc** (default output). Create `.planning/audit[-<scope>]/status.md` and write it **in the planning-doc checkbox protocol** — see the `planning-docs` skill and the "Planning and Persistence" section of the global `CLAUDE.md`. Do not invent a separate format or location. Use `assets/output-template.md` as the skeleton.
    - Each finding is a `- [ ]` item the user triages (`[x]` accept / `[-]` dismiss); genuine questions are `- [?]`, pure observations `- [i]`.
    - Tag every finding with **`#priority/{high,med,low}`**, **`#effort/{quick,moderate,involved}`**, and **`#category/{…}`**. Group by `#priority/*`, with a **low-hanging-fruit** callout (`#priority/high #effort/quick`) up top.
    - **Output-mode variants** (only when `$ARGUMENTS` asks): inline `// TODO: [AUDIT] …` comments instead of a doc; or no doc at all (report in chat).

6. **Stop and hand off.** Summarize the findings doc in chat and **halt — make no code changes.** Offer next steps: go deeper on deprioritized areas, or enter fix-mode.

7. **Fix-mode (only on request).** Read `reference/doc-lifecycle.md`, then resolve accepted findings one at a time, committing per item, marking items done and pruning the doc as you go, and re-passing for anything missed.

## Files

- `reference/categories.md` — the finding checklist + `#category/*` tags. **Read in step 2, every run.**
- `reference/doc-lifecycle.md` — the create → triage → fix-per-commit → prune → re-pass lifecycle. **Read in step 7 only.**
- `assets/output-template.md` — skeleton for the findings doc (step 5).
