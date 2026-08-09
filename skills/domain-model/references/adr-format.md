# ADR format

ADRs live in `docs/adr/`, sequentially numbered: `0001-slug.md`,
`0002-slug.md`. Create the directory lazily — when the first ADR is needed.

In a multi-context repo, system-wide decisions go in the root `docs/adr/` and
context-specific ones in that context's own `docs/adr/`. When unsure, ask which
it is; a decision filed in the wrong place is invisible to the people it binds.

## Template

```md
# {Short title of the decision}

{1–3 sentences: the context, what was decided, and why.}
```

That is the whole requirement. An ADR can be one paragraph. The value is in
recording *that* a decision was made and *why* — not in filling out sections.

## Optional sections

Add these only when they earn their place. Most ADRs need none of them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by
  ADR-NNNN`) — worth it once decisions start being revisited.
- **Considered options** — when the rejected alternatives are worth
  remembering, because someone will propose them again.
- **Consequences** — when a non-obvious downstream effect needs calling out.

## Numbering

Scan `docs/adr/` for the highest number and add one. Never renumber: the number
is the ADR's identity and other documents cite it.

## When an ADR is warranted

All three must hold:

1. **Hard to reverse** — changing your mind later costs real work.
2. **Surprising without context** — a future reader will look at the code and
   wonder why on earth it was done this way.
3. **The result of a real trade-off** — there were genuine alternatives and one
   was picked for specific reasons.

### What clears the bar

- **Architectural shape.** "The write model is event-sourced; reads are
  projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate
  via domain events, never synchronous HTTP."
- **Technology choices carrying lock-in.** Database, message bus, auth
  provider, deployment target, cross-platform framework. Not every library —
  the ones that would take a quarter to swap.
- **Boundary and scope decisions.** "Customer data is owned by the Customer
  context; others reference it by id only." The explicit no's are worth as much
  as the yes's.
- **Deliberate deviations from the obvious path.** "Hand-written SQL instead of
  an ORM, because X." These stop the next engineer from "fixing" something that
  was intentional.
- **Constraints invisible in the code.** A compliance rule that rules out a
  cloud region; a partner contract that caps response times.
- **Rejected alternatives whose rejection was subtle.** Otherwise the same
  suggestion returns in six months and gets re-argued from scratch.

### What does not

- Anything a single PR could undo.
- Following the framework's default.
- A decision with no alternative — "we did the obvious thing" is not an ADR.
- Restating what the code plainly says.

## Superseding

A decision that is overturned is not deleted. Mark the old ADR
`superseded by ADR-NNNN` and write a new one that says what changed and why the
original reasoning stopped holding. The overturned reasoning is often the most
useful thing in the directory — it is the argument someone will otherwise make
again.
