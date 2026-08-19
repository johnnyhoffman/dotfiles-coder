---
name: planning-docs
description: Grammar and workflow for planning/status docs (e.g. `.planning/<task-slug>/status.md`) — a checkbox + tag protocol for async agent↔user communication. Use when creating or updating a planning doc, asking the user questions in one, or incorporating their inline responses.
---

# Planning Doc Conventions

How to write and maintain planning/status docs. The user reviews these asynchronously in nvim and responds inline by toggling checkboxes and adding items. *Whether* to use a planning doc and *which channel* to route questions through live in the global CLAUDE.md; this skill is the protocol once you're in one.

Communication happens through list items whose checkbox encodes state. Three orthogonal axes:

- **Axis 1 — base glyph (box position 1) = kind / voice / source.** Persists; never overwritten.
- **Axis 2 — acknowledgment (box position 2 = `x`) = loop closed.** Applies to `?`, `>`, `<`; the base glyph stays visible (a closed question reads `- [?x]`, not an anonymous `- [x]`).
- **Axis 3 — tags = metadata.** Composable; each sits on the item it describes — some on the `- [?]` anchor, some on a specific option (see [[#Tags]]).

These are non-standard checkbox glyphs; the user renders them in nvim. Don't worry about how they display elsewhere.

## The glyph is always a full list item

**A checkbox glyph is only ever valid as the marker of a list item — written as `- [<glyph>] <content>` (or nested with leading indentation), with content following it on the same line.** The `- ` is part of the syntax, not optional shorthand.

- Never write a bare glyph (`[?]`, `[x]`, `[/]`, `[>]`, etc.) on its own — not mid-sentence, not inside a heading, not as a standalone token in prose. It is meaningless except as a list-item checkbox.
- This skill writes glyphs in their full `- [...]` form everywhere for that reason; mirror it in the docs you author. If you find yourself wanting to reference a state in prose, name it ("the open question", "the accepted option") rather than dropping a bracket glyph into the sentence.

## Structure and location

- Location: `.planning/<task-slug>/status.md` inside the project repo, unless a central planning repo is configured — then use that.
- Track current status, decisions (with rationale), and the Q&A. Keep it reflecting the latest state, not just the initial plan.

## Vocabulary

**Base glyph (position 1):**

- `- [ ]` — menu option, undecided
- `- [x]` — menu option, **accepted** (standard checked box)
- `- [-]` — ruled out / dropped — an option declined, an option excluded by resolving a `#select-one` (see [[#Each pass (the re-pass sweep)]]), or any item you're abandoning
- `- [?]` — **your** question / decision for the user · *agent-only — never author any other glyph's question; the user scans for `- [?]` items to see what you need*
- `- [>]` — **user** voice — reply, concern, question, or comment · *user-authored, may appear anywhere*
- `- [<]` — **your** voice — answer / response · *nested one level under the item it addresses*
- `- [i]` — info / context note, no response needed
- `- [:]` — cross-reference pointer ("answered/discussed elsewhere"), e.g. `- [:] see thread B`
- `- [/]` — **partial.** Two uses:
    - *Partially resolved* (agent-set, sparingly): a multi-part answer is half-given, or you're mid-incorporation.
    - *Partially accepted* (user-set): a third option toggle on a menu/confirm box, parallel to `- [x]` (accept as-is) and `- [-]` (reject) — "take this one, but with a change." See [[#Partial accept on menus]] for the full mechanics.

**Acknowledgment suffix (position 2 = `x`)** — the base glyph is preserved:

- `- [?x]` — your question is fully answered and incorporated · *you set it*
- `- [>x]` — a user item you've addressed · *you set it*
- `- [<x]` — your answer, acknowledged by the user · *the user sets it*

(Menu options are toggled directly — `- [ ]` → `- [x]` accept, `- [-]` reject, `- [/]` accept-with-change — so the `x`-suffix axis is only for `?`/`>`/`<`.)

## Tags

Tags fall in two placement groups: those that mark **a specific option/answer** sit on that line; those that **qualify the question as a whole** sit on the `- [?]` anchor. Putting an option-level tag on the anchor is the most common mistake — keep them on the line they actually describe.

*Option/answer-level (on the specific line):*

- `#recommended` — marks the option or answer you prefer. **Never on the `- [?]` question line** — a question isn't something you recommend; the recommendation is one of the choices under it. The tag is the whole signal — don't also restate "(recommended)" in the option text.
- `#default` — marks the option that will be taken if the question goes unanswered; silence = consent. Put it on the **option line** (it stacks with `#recommended` when the same choice is both). Only for a free-form question with *no* options to tag, state the fallback inline on the anchor as `#default=<value>`. A `#default` already makes a question non-blocking, so don't also tag it `#optional`.

*Question-level (on the `- [?]` anchor):*

- `#optional` — an answer isn't required and you won't assume one; don't nag about it.
- `#select-one` / `#select-any` — single- / multi-select menu.
- `#select-each` — an independent confirm-list, where each item is decided on its own (visually distinct from a menu).

## Asking and answering

- **You ask** with a `- [?]` item (optionally with nested `- [ ]` options + a `#select-*` tag for a menu). Every open `- [?]` is assumed to need an answer — warn the user at hand-off about unanswered ones, unless tagged `#optional` or carrying a default (a `#default` option, or `#default=` on the anchor).
- **Every ask is a `- [?]` item — never prose.** A decision solicited in body text ("say which", "let me know", "your call") has no open checkbox, so the user scanning for open boxes glances right past it and can't confirm they've responded everywhere. If it expects a response, it gets the `- [?]` treatment; prose may *explain* a question, never *be* one.
- **The user asks** with a `- [>]` item. You answer in a nested `- [<]` and mark their item `- [>x]`; the user later marks your `- [<]` → `- [<x]` once satisfied. The user never authors a `- [?]`.
- **A free user concern** is a top-level `- [>]` anywhere in the doc. Address it (nested `- [<]`, fold into the prose, or open a `- [?]` if you need a decision back), then mark it `- [>x]`.

## Partial accept on menus

`- [/]` as *partially accepted* is a **user action on an existing option box** — never an option you pre-author. The user takes one of your `- [ ]` options but wants it adjusted, so they toggle it `- [/]` instead of `- [x]`. It only applies where option boxes exist:

- **`#select-one` / `#select-any`** — toggle the chosen option `- [/]` instead of `- [x]`.
- **`#select-each`** — `- [/]` = keep this item, but modified.
- **Free-form `- [?]` (no nested options)** — there is no box to toggle, so `- [/]` does not apply; the user gives a qualified answer in a nested `- [>]` instead. Don't manufacture an option just to host a `- [/]`.

**Where the modification lives:** canonically a nested `- [>]` child of the toggled option (this is what you scan for). It may instead point at an answer elsewhere in the doc that explicitly conflicts with the option as written. A `- [/]` with no modification stated anywhere is incomplete — flag it in chat rather than guessing.

**Resolving it (next pass):** read the modification, reconcile it, and write the accepted-as-modified outcome into the prose; close the nested `- [>]` → `- [>x]`. If the tweak itself needs a decision back, open a fresh `- [?]`. Once fully incorporated, **flip the option `- [/]` → `- [x]`** — the same closure as `- [?]` → `- [?x]`; the record of the compromise survives in the resolved `- [>x]` thread and the prose.

```markdown
- [?] Which renderer are we targeting? #select-one
    - [/] nvim with custom glyphs
        - [>] but keep a GitHub-safe fallback for when docs render on the web
    - [ ] GitHub web
```

## Each pass (the re-pass sweep)

Except on the pass that first creates the doc:

1. Address every open `- [>]` → mark `- [>x]`.
2. Incorporate answers into the prose, then close every answered `- [?]` → `- [?x]`. When you close a `#select-one`, also rule out its unchosen options (`- [ ]` → `- [-]`) — the single pick excludes them, and leaving them open reads as "still to decide." **Don't** do this for `#select-any` / `#select-each`: there an open `- [ ]` means *not yet decided*, and the user declines options explicitly.
3. Rewrite a **`## Changes this pass`** section near the top — wiped and replaced each pass — summarizing what changed, with `[[#Section]]` wikilinks.
4. In chat, echo the **open set**: every open `- [?]` (awaiting the user's answer) and every `- [<]` (awaiting their acknowledgment). The doc is the content layer; chat is the notification layer.

## Discipline

- **Open vs settled:** a box is *open* — review still owed by someone — when it's `- [ ]`, `- [?]`, `- [>]`, `- [<]`, or `- [/]`; it's *settled* — no action pending — when it's `- [x]`, `- [-]`, `- [?x]`, `- [>x]`, `- [<x]`, `- [i]`, or `- [:]`. The user scans for open boxes to find what still needs attention, so don't leave anything falsely open: when a thread resolves, every box under it should land in a settled state (e.g. ruling out the losers of a resolved `#select-one` — see the sweep, step 2).
- **Source of truth:** checkbox state is the *negotiation layer*; the plan prose is the *truth*. A decision is "done" only once its outcome is written into the body — not merely when a box is closed.
- **Nesting:** your `- [<]` replies nest one level under the item they address. Keep threads shallow otherwise; summarize deep resolutions in prose.
- **Your own content** (proposals, recommendations, emphasis) uses plain paragraphs, bullets, or bold — never markdown blockquotes (`>`). Blockquotes are not part of this protocol.
- **Stray prose detection:** if the user writes prose into the doc *without* a `- [>]` marker, clarify **in chat** (not in the doc) whether it was meant as input or the marker was omitted by mistake. Linting / whitespace changes are not content.

## Example

```markdown
## Changes this pass

- Resolved the schema-layout question; see [[#Partial accept on menus]].

## Open threads

- [?] Which renderer are we targeting? #select-one
    - [ ] nvim with custom glyphs #recommended #default
    - [ ] GitHub web
- [?x] Which schema layout? #select-one
    - [x] flat single-table
        - [>x] keep it flat, but split `meta` into its own table
    - [-] fully normalized
- [>x] New idea: auto-number threads for cross-refs?
    - [<] Good thought — tracked as thread A.
- [?] Does the schema drafted in the body cover your cases? #optional
```
