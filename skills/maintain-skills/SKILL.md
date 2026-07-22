---
name: maintain-skills
description: >
  Meta-skill for keeping a skill library correct as the codebase evolves — both
  the shared adora-skills plugin and a project's own .claude/skills/. Use when
  the user asks to update, refresh, audit, or re-sync skills, says a skill
  taught something wrong or is out of date, after a big refactor / rename /
  module move, after CONTEXT.md or an ADR changes, when adding a new domain that
  needs a skill, or when deciding whether to update an existing skill, write a
  new one, or delete one.
---

# Maintain Skills

Keep every skill grounded in the code it describes. The standard: **a skill that
cites a dead path, dead symbol, or stale command is worse than no skill** — it
makes a cheap session confidently wrong.

## Which library are you maintaining?

Work out the target before editing anything — they have different rules.

| Target | Lives in | Rule |
| --- | --- | --- |
| **Shared skills** (this plugin) | the `adora-skills` repo, `skills/<name>/SKILL.md` | Must stay **project-agnostic**. No repo-specific paths, baselines, bundle ids, or module names. Teach Claude to *read* the specifics from the repo it is in. |
| **Project skills** | `<project>/.claude/skills/` | May be as concrete as you like — cite real paths, real symbols, real baselines. Concreteness is the point. |
| **Third-party skills** | installed plugins (e.g. `mattpocock-skills`) | Read-only. Never edit; if one is wrong, note it and work around it. |

Plugin skills are installed as a read-only bundle. To change one, edit it in the
`adora-skills` repo, push, and run `/plugin marketplace update adora-skills`.
Editing the installed copy does nothing durable.

**The promotion test.** A project skill earns promotion into the shared plugin
only when it is useful in a *second* project without rewriting its body. If
generalizing it would strip out the specifics that make it good, it belongs in
the project, not the plugin.

## The grounding standard

Every skill must satisfy:

1. Every file path it cites exists (in the repo, for project skills; in the
   skill's own directory, for shared ones).
2. Every exported symbol it names still exists at the cited path.
3. Every command it gives matches an actual `package.json` script, or is a
   verified binary invocation.
4. Code snippets are copied from real code, with the source path named above
   the snippet.
5. Domain vocabulary matches `CONTEXT.md` exactly — never the `_Avoid_` synonyms.
6. Project skills carry a `**Last synced**: DD.MM.YYYY` line near the top of the
   body. Shared skills should not — they have no single repo to be synced against,
   and a date there is a false promise.
7. It does not duplicate `CLAUDE.md` / `AGENTS.md` wholesale — those are
   auto-loaded; skills add procedure, deep pointers, and judgment.

## Drift-check procedure

Run this per skill whenever one is suspected stale, or after any large
refactor or rename.

1. **Extract citations.** Grep the skill for paths and symbols:

   ```bash
   grep -oE '(src|docs|i18n)/[A-Za-z0-9_./-]+' <skill>/SKILL.md | sort -u
   ```

   Scan its `references/*.md` too.
2. **Verify paths.** `test -f <path>` each one. Any miss is drift — find where
   the file moved (`git log --follow`, grep for the symbol) and fix the citation.
3. **Verify symbols.** Grep the cited file for each named export or function.
   Renamed symbols are the most common silent drift.
4. **Verify commands.** Check named scripts against the `scripts` block in
   `package.json`. Re-run cheap factual claims — a skill that records "typecheck
   is currently clean" must have that re-verified, not trusted.
5. **Diff the sources of truth.** For project skills, check what changed since
   the Last synced date:

   ```bash
   git log --since=<last-synced> --oneline -- CLAUDE.md AGENTS.md CONTEXT.md docs/adr eslint.config.mjs package.json
   ```

   Read the diffs and reconcile the skill with any new terms, rules, moved
   modules, or changed commands.
6. **Fix, then bump.** Apply corrections, re-verify each fix **against the repo,
   never from memory**, and only then update the Last synced date. A fresh date
   on an unchecked skill is a lie.
7. **Re-read the frontmatter description** against the quality bar below.

For a shared skill, step 5 inverts: instead of syncing to one repo, check the
skill against **two or more** projects. Anything true in only one of them is a
project specific that should be removed or turned into "read this from the repo".

## Update vs new skill vs delete

- **Update** when the topic is unchanged but details drifted: moved files,
  renamed symbols, new edge rules, changed commands. Keep the skill name and
  triggers stable — renaming breaks cross-references and user muscle memory.
- **Write a new skill** when a genuinely new domain or workflow appears. Follow
  the existing format: frontmatter description with concrete triggers,
  procedure-first body, key-files table, real snippets with source paths, danger
  zone, definition of done. Keep `SKILL.md` under ~350 lines; overflow goes to
  `references/<topic>.md` in the skill directory.
- **Delete** when the workflow the skill teaches no longer exists, or another
  skill fully covers it (merge the unique content first). A misleading zombie
  skill still fires on its triggers. Remove the whole directory, then remove its
  row from any inventory and every cross-reference:
  `grep -rn '<name>' skills/ .claude/skills/`.

**Check the dependency first.** Before writing a new skill, check whether an
installed plugin already covers it — duplicating a dependency's skill means two
descriptions competing for the same trigger, and the worse one sometimes wins.

## CONTEXT.md and ADR changes route through domain-modeling

Skills consume the domain model; they do not own it. When maintenance reveals
that terminology or a decision itself is wrong or missing, do not edit
`CONTEXT.md` or `docs/adr/` ad hoc from here — run `domain-modeling` to change
the model. After the model changes, re-sync every skill that uses the affected
terms: `grep -rln '<term>'` to find them, then drift-check each. The dependency
is one-way: model first, skills follow.

## Frontmatter description quality bar

The description is the **only** text the model sees when deciding whether to
load a skill. A smaller model must fire on it from a vague user message.

- Third person; says what the skill does **and** when to use it; 2–6 sentences.
- Includes literal trigger phrasing users actually type — "broken", "update the
  skills", "commit this" — not just abstract topic nouns.
- Broad enough to catch paraphrases (list several trigger forms), specific
  enough not to fire on unrelated work.
- Names the files or areas whose modification should trigger it ("before
  touching modules/sync") when that applies.
- Bad: "Helps with sync." Good: concrete verbs, symptoms, and named surfaces.
- `disable-model-invocation: true` is only for pure slash-command wrappers.

## Danger zone

- **Never "fix" a skill from memory.** Every correction must be re-verified
  against the repo at edit time — otherwise you replace one hallucination with
  another.
- **Never bump Last synced without running the full drift check.** The date is
  the library's trust signal.
- **Never edit an installed plugin's skills in place** — the change is silently
  discarded on the next update. Edit the source repo.
- **Never leak project specifics into a shared skill.** A hardcoded module name
  or bundle id teaches the wrong thing in every other project.
- **Do not edit CONTEXT.md or ADRs from here** — route through `domain-modeling`.
- **Do not let skills restate CLAUDE.md / AGENTS.md** — duplication drifts
  independently and the copies will disagree.
- **Do not delete a skill without removing cross-references** — sibling skills
  that say "run `<name>`" would then point at nothing.

## Definition of done

- [ ] Every touched skill passed the full drift check; fixes verified against
      the repo, not memory.
- [ ] Last synced dates bumped only on fully checked project skills.
- [ ] Any inventory table updated (rows added and removed).
- [ ] Frontmatter descriptions of touched skills meet the quality bar.
- [ ] Cross-references between skills still resolve.
- [ ] Shared skills contain no project-specific paths, commands, or names.
- [ ] Nothing outside the skill library was modified by this maintenance pass.
