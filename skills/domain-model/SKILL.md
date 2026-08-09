---
name: domain-model
description: >
  Build and sharpen a project's domain model — the `CONTEXT.md` glossary of
  terms and the `docs/adr/` record of architectural decisions. Use when the
  user wants to pin down terminology or a ubiquitous language, asks "what
  should we call this", says the glossary is wrong or missing a term, wants to
  record or revisit an architectural decision ("write an ADR", "record why we
  did this"), or when another skill needs the model changed rather than merely
  read. Also use mid-design, the moment a term or a hard-to-reverse decision
  crystallises. NOT for reading `CONTEXT.md` for vocabulary — that is a habit
  every skill has, not a reason to load this one.
---

# Domain Model

Own the project's shared language and its recorded decisions. This is the
*active* discipline: challenging terms, inventing scenarios that break them,
and writing the glossary and the ADR down the moment they crystallise — not
after the feature ships, when the reasoning is gone.

Two artifacts, and they do not overlap:

| File | Holds | Never holds |
| --- | --- | --- |
| `CONTEXT.md` | What the project's nouns *mean* | Implementation, structure, plans, TODOs |
| `docs/adr/NNNN-slug.md` | Why a hard-to-reverse decision was made | Anything easy to reverse or unsurprising |

## Ground yourself first

Read before writing. The model that already exists outranks the one in your
head.

1. Look for `CONTEXT-MAP.md` at the root. If it exists, the repo has **multiple
   contexts** — read it to find which `CONTEXT.md` the current topic belongs
   to, and ask if it is genuinely unclear.
2. Otherwise read the root `CONTEXT.md`. If neither exists, the repo has no
   model yet — create files **lazily**, when the first term or decision
   actually lands, never as an empty scaffold.
3. Skim `docs/adr/` for decisions that already constrain the topic. A term you
   are about to coin may already be settled there under another name.

```text
Single context (most repos)      Multiple contexts
/                                /
├── CONTEXT.md                   ├── CONTEXT-MAP.md
├── docs/adr/                    ├── docs/adr/            ← system-wide
│   ├── 0001-….md                └── src/
│   └── 0002-….md                    ├── ordering/CONTEXT.md
└── src/                              │   └── docs/adr/    ← context-local
                                      └── billing/CONTEXT.md
```

Formats: [references/context-format.md](./references/context-format.md) and
[references/adr-format.md](./references/adr-format.md).

## During a design session

### Challenge against the glossary

When a term conflicts with what `CONTEXT.md` already says, call it out at
once — do not silently adopt the new usage. "The glossary defines *cancellation*
as the whole order being voided, but you seem to mean a single line item.
Which is it, and does the other one need its own word?"

### Sharpen fuzzy language

Vague or overloaded words are where the bugs come from. Propose a precise
canonical term and one to avoid. "You're saying *account* — do you mean the
Customer or the signed-in User? Those diverge the moment one person has two
profiles."

### Break it with a scenario

Do not accept a definition on its own terms. Invent the specific case that
sits on the boundary and see whether the definition survives it. "A user
deletes their last entry, then the sync from their other device brings it
back. Is that entry *restored* or *created*? Whichever word we pick decides
whether the timestamp changes."

### Cross-reference with code

When the user states how something works, check whether the code agrees.
Contradictions are the most valuable thing this skill finds: "The reducer
cancels the whole order and there is no per-item path, but you just described
partial cancellation — is the code behind, or is the model?"

### Write it down inline

Resolve a term, update `CONTEXT.md` in that turn. Land a qualifying decision,
write the ADR in that turn. Batching to the end of the session is how the
reasoning gets lost and the entry ends up as a bare conclusion nobody can
argue with later.

## The ADR bar

Offer an ADR only when **all three** are true:

1. **Hard to reverse** — changing your mind later costs real work.
2. **Surprising without context** — a future reader will look at this and
   wonder why on earth it was done this way.
3. **The result of a real trade-off** — there were genuine alternatives and one
   was picked for specific reasons.

Miss any one and skip it. Easy to reverse? You will just reverse it.
Unsurprising? Nobody will wonder. No alternative? There is nothing to record
beyond "we did the obvious thing." An ADR directory full of non-decisions
trains people to stop reading it.

What clears the bar, and what to write, is in
[references/adr-format.md](./references/adr-format.md).

## After the model changes

The model leads; everything else follows. When a term is renamed or an ADR
supersedes an earlier one:

1. `grep -rn '<old term>'` across the repo — code, docs, skills, tickets. Note
   what still uses the old word. Renaming code is a separate change with its
   own review; do not smuggle it into a glossary edit, but do not leave the
   divergence unmentioned either.
2. Skills that teach the old vocabulary are now wrong. Re-sync them —
   `maintain-skills` carries the drift check.
3. An ADR that replaces another does not delete it. Mark the old one
   superseded, so the reasoning that was overturned stays readable.

## Danger zone

- **`CONTEXT.md` is a glossary and nothing else.** Not a spec, not a scratch
  pad, not a home for implementation decisions. The moment it collects "how",
  it stops being trustworthy for "what".
- **No general programming concepts in the glossary.** Timeouts, retries,
  adapters and error types belong to the craft, not to this project's domain,
  however much the project uses them. Before adding a term: would another
  project in a different industry need this word to mean this thing?
- **Never invent a term the user didn't agree to.** You propose; they decide.
  A glossary containing words only the agent uses is worse than no glossary.
- **Never create empty scaffolding** — no `CONTEXT.md` with a heading and no
  terms, no `docs/adr/` with a README. Lazily, on first real content.
- **Never renumber ADRs.** The number is the identity; other documents cite it.
  Scan for the highest and increment.
- **Do not let a definition list what a thing *does*.** Define what it *is*;
  behavior drifts, identity doesn't.

## Definition of done

- [ ] Existing `CONTEXT.md` / `CONTEXT-MAP.md` / `docs/adr/` were read before
      anything was written.
- [ ] Every term resolved in the session is in the glossary, with its rejected
      synonyms under `_Avoid_`.
- [ ] Every glossary entry says what the thing is, in one or two sentences, and
      carries no implementation detail.
- [ ] Any decision written as an ADR clears all three tests; any that didn't
      was skipped, not written anyway.
- [ ] New ADRs use the next free number; superseded ones are marked, not
      deleted.
- [ ] Code, docs, and skills still using a renamed term were found and the
      divergence reported.

---

Inspired by `domain-modeling` in
[mattpocock/skills](https://github.com/mattpocock/skills).
