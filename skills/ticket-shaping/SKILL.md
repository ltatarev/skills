---
name: ticket-shaping
description: >
  Turn a UX/design-level description of a feature or change into an
  implementation-ready ticket in whichever tracker the repo uses (Linear,
  Notion, or in-repo docs/tickets) — UX spec plus a concrete, file-level
  recommended implementation plan the user challenges before it is
  written down. The user describes how something should behave and look, NOT
  the technical approach; this skill interviews them one question at a time,
  drafts the plan, hands it to `grilling`, then writes the ticket(s). Trigger
  when the user says "shape this", "write a ticket", "let's spec", "I want the
  app to…", "it should feel like…", "turn this idea into a task", or describes
  desired behavior/looks and asks to capture it for later implementation. NOT
  for stress-testing an already-written plan (that's `grilling` on its own) and
  NOT for actually building the feature.
---

# Ticket Shaping

Take a fuzzy product idea from the user's head to a written ticket that a fresh
agent — different session, smaller model, zero conversation history — can
implement without asking a single follow-up question. The user speaks UX. The
ticket speaks UX *and* carries a recommended implementation plan concrete
enough to argue with. You are the translator, and you are the one who proposes
the technical approach — the user's job is to challenge it, not to author it.

**Source of truth**: the configured tracker (output home — see below),
`AGENTS.md` / `CLAUDE.md`
(conventions and non-negotiables every ticket must respect), `CONTEXT.md`
(domain vocabulary — use the user's words, but map them onto these terms),
`docs/adr/` (decisions already made; a plan that contradicts an ADR needs a new
ADR). Read whichever of these the repo actually has before shaping anything.

## Where the ticket goes

Shaped tickets land in whatever tracker the repo uses, recorded in
`.claude/ticket-tracker.json`:

```json
{ "tracker": "linear", "team": "ABC", "inProgressStatus": "In Progress", "inReviewStatus": "In Review" }
{ "tracker": "notion", "database": "<database URL or id>", "statusProperty": "Status",
  "inProgressStatus": "In Progress", "inReviewStatus": "In Review" }
{ "tracker": "repo", "path": "docs/tickets", "filePattern": "NNN-slug.md" }
```

Read that file before shaping. If it does not exist, this is the first run in
this repo — look for evidence (an existing `docs/tickets/` directory, Linear MCP
tools plus `ABC-123` style commit prefixes, Notion MCP tools plus Notion links in
the README), then ask the user which tracker this project uses and lead with what
you found. Write the answer to `.claude/ticket-tracker.json` and commit it, so
this and `implement-ticket` never ask again. Never assume a tracker.

For `repo`, the backlog is one file per ticket under the configured `path`,
numbered per `filePattern`, picked up by any agent straight from the codebase.
Create the directory lazily, when the first ticket is written.

## The workflow

### 1. Listen, then ground

Let the user describe the whole idea in their own words first — don't interrupt
the initial description with questions.

Then, **before asking anything**, answer what you can yourself:

- Read `AGENTS.md` / `CLAUDE.md` and `CONTEXT.md`. Skim the feature modules this
  touches and their public surfaces (barrel `index.ts` files).
- Check `docs/adr/` for decisions that constrain the approach.
- Check the tracker's existing tickets for overlap, or for a ticket this should
  amend instead of duplicate (`list_issues` / `notion-query-data-sources` / the
  configured directory).
- Check what state/persistence already exists versus what the idea implies.

Never ask the user a question the codebase or docs can answer. Their time is
for product decisions only.

### 2. Interview — one question at a time

Grilling style: **one question per turn, always with your recommended answer**,
waiting for the reply before the next. Never batch. Walk the branches in
dependency order — an answer often kills whole branches of later questions.

Cover these domains (skip any the initial description already settled):

1. **The moment** — who is doing what, where in their day, when this matters.
   What were they doing right before?
2. **Entry point** — from which screen or gesture is this reached? Discoverable
   or tucked away?
3. **Happy path** — the core interaction, step by step, in the user's words.
   What does the user see change at each step?
4. **States** — empty, first-use, loading, error. What does airplane mode look
   like? Does it still feel good once the data set is large?
5. **Edge cases** — duplicates, missing data, deleted data, mid-flow
   interruption, app killed and relaunched. If anything is destructive: confirm
   and undo story.
6. **Look & motion** — which existing screens should it feel like? Any
   animation moments? (House defaults: shared `theme/ui` primitives, theme
   tokens only, no color literals, all user-facing text through i18n — see
   `build-ui`.)
7. **Data implications, asked in UX terms** — "should this survive an app
   restart?", "is this per entry or global?", "does it need to be remembered
   across launches?". You translate the answers into persistence and state
   notes for the plan.
8. **Non-goals** — what a reasonable implementer might assume is included but
   isn't. Get at least one explicit exclusion.
9. **Done, from the couch** — how will the *user* verify it on their phone?
   These become the acceptance criteria.

**Stop condition — the cold-pickup test**: imagine handing only the ticket text
to a fresh agent. If any plausible clarifying question remains whose answer
isn't in the ticket, keep interviewing. When the answer to "what would they
ask?" is "nothing product-level", stop.

### 3. Scope the cut — your call

Decide silently whether this is one ticket or several. Do not ask the user to
arbitrate splits. Split when pieces are independently shippable and testable on
device; keep together when one piece is meaningless without the other. Aim for
roughly one focused commit-day per ticket. Note dependencies between split
tickets in each ticket's plan.

### 4. Draft the recommended implementation plan

Now switch hats: you have the product spec, so design the implementation
yourself. This is a real proposal, not a routing table. It must be concrete
enough that the user can disagree with a specific line.

The plan states:

- **Approach and why** — one paragraph. Which module owns this, whether
  anything new is created, what existing machinery it leans on.
- **Steps, module by module** — real paths from this repo, in the order you
  would do them, each one a sentence about what changes. Call out new files, new
  exports from a module's `index.ts`, new slices or selectors, new shared UI
  primitives, new i18n keys.
- **Data and persistence** — new state shape, what is persisted and what is
  derived, and what happens to data written by an older build.
- **Rejected alternatives** — at least one, with the reason. Cheap to write,
  and it is where the user most often disagrees.
- **Risks and open bets** — the step you are least sure about, and what would
  make you change approach.
- **Validation** — which checks this warrants (see `validate-change`) and what
  to test on device (see `verify`).

Check the plan against the repo's own non-negotiables before showing it — read
them from `AGENTS.md` / `CLAUDE.md` rather than assuming. In these projects they
typically include: module boundaries (public surface imports only), theme tokens
rather than literals, i18n for all user-facing text, adapters instead of direct
native SDK use, `FlatList` for long lists, `scheduleOnRN` rather than `runOnJS`.
If the plan needs an exception to any of them, say so explicitly rather than
quietly breaking it. If it contradicts an ADR in `docs/adr/`, flag that the
ticket also needs a new ADR — invoke `domain-modeling` when it does.

### 5. Present, then get grilled

Show the user the drafted ticket in full — UX sections and plan together — then
invoke the `grilling` skill on the **plan** specifically. One question per
turn, each with your recommended answer, until the user is satisfied. Expect
the plan to change; expect some answers to reach back and change the UX
sections too. Rewrite the draft in place after each round rather than
accumulating amendments in conversation.

The shaping is done when the user says so, not when you run out of questions.

### 6. Write the ticket(s)

Where, by tracker:

| Tracker | Destination |
| --- | --- |
| `repo` | `<path>/NNN-slug.md` — next free number, kebab-case slug |
| `linear` | `save_issue` on the configured `team`; sections below become the description, title from the `#` line |
| `notion` | `notion-create-pages` in the configured `database`; sections below become the page body |

The section order and headings are the same everywhere — only the container
changes. For Linear and Notion, set the status to the configured
`inProgressStatus`'s backlog equivalent (ask once if the tracker has no obvious
"shaped/todo" state) and drop the `**Status:**` / `**Depends on:**` lines in
favor of the tracker's own fields.

```markdown
# NNN · <Title in user language>

**Status:** Shaped · <date>
**Depends on:** <ticket numbers, or —>

<One-paragraph summary: the moment, the user, the payoff.>

## Behavior

<Happy path, step by step, from the user's point of view. Screens named as the
user sees them.>

## States & edge cases

<Empty / loading / error / offline / large data set, plus every edge case
decided in the interview. Destructive actions: the confirm and undo story.>

## Look & motion

<Reference screens, primitives to match, animation moments. UX language —
"feels like the journal list", not component names.>

## Out of scope

<Explicit exclusions from the interview.>

## Acceptance criteria

- [ ] <User-verifiable, on-device checks. Each one testable from the couch.>

## Recommended implementation

**Approach:** <one paragraph — owning module, what is new, what is reused.>

**Steps**

1. `src/modules/…` — <what changes>
2. `src/theme/ui/…` — <what changes, or "no new primitives">
3. `i18n/<locale>.json` — <new keys>
4. …

**Data & persistence:** <state shape, what persists, older-build data.>

**Rejected:** <alternative — reason.>

**Risks:** <least certain step; what would flip the approach.>

**Validation:** <commands to run; what to check on device.>

**Constraints touched:** <house rules this brushes against, plus any ADR that
applies or is needed.>
```

Rules for the ticket text:

- Everything above "Recommended implementation" stays in **user/UX language** —
  no component names, no file paths, no library names.
- "Recommended implementation" is a **recommendation**. The implementing agent
  may deviate, but must say why in the commit or PR body.
- An "Open questions" section is a shaping failure. If one would be non-empty,
  the interview isn't finished.

### 7. Pickup protocol (what the implementing agent does)

`implement-ticket` is the counterpart that picks these back up, from the same
tracker and the same config file. It moves the ticket to `inProgressStatus` when
starting and `inReviewStatus` when handing off — for `repo`, that is the
`**Status:**` line (`In progress · <date>`, then `Done · <date> · <commit>` when
merged). Shaping sessions that amend an existing ticket bump its date instead of
creating a near-duplicate.

## Adapting to a project that differs

- **Different ticket location or naming scheme** → record it in
  `.claude/ticket-tracker.json` (`path`, `filePattern`), follow the repo's, and
  keep the section order of the template.
- **A tracker not in the config's three** (GitHub Issues, Jira) → shape exactly
  the same way and write the result there; note the tracker name in the config
  file so `implement-ticket` reads the same answer.
- **The repo's non-negotiables differ** from the ones listed in step 4 → use the
  repo's. Read `AGENTS.md` / `CLAUDE.md`; do not carry another project's rules in.

If the change is to this skill itself rather than to a project, see
`maintain-skills` — this is a shared plugin skill, so edit it in the
`adora-skills` repo, not in the installed copy.
