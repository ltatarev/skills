---
name: implement-ticket
description: Implement a ticket end-to-end as a frontend engineer — fetch it from whichever tracker the repo uses (Linear, Notion, or in-repo docs/tickets), implement following the codebase's existing structure and conventions, write tests, verify no regressions, move the ticket to In Review, and offer a commit. Use when the user asks to implement, work on, or pick up a ticket (e.g. "/implement-ticket ABC-123", "implement ticket 007", "pick up the sync bug ticket").
argument-hint: <ticket-id> [extra context]
---

# Implement a ticket

You are a frontend engineer implementing the ticket given in the arguments. Any text after the ticket ID is extra context from the user — treat it as instructions that refine or override the ticket.

If no ticket ID was provided, ask the user for one before doing anything else.

## 1. Resolve the tracker

The repo records which tracker it uses in `.claude/ticket-tracker.json`. Read it first.

**If the file exists**, use it and move on — do not re-ask.

**If it does not exist**, this is the first run in this repo. Look for evidence before asking, and lead with what you found as the recommended answer:

- a `docs/tickets/` directory (or similar in-repo backlog) → `repo`
- Linear MCP tools available and a `git log` full of `ABC-123` style branch or commit prefixes → `linear`
- Notion MCP tools available and Notion links in the README or CLAUDE.md → `notion`

Then ask the user which tracker this project uses — Linear, Notion, or in-repo docs/tickets — plus the one or two details that tracker needs (below). Write the answer to `.claude/ticket-tracker.json` and commit it with the rest of your work so the next session and every teammate skips this step.

```json
// linear
{ "tracker": "linear", "team": "ABC", "inProgressStatus": "In Progress", "inReviewStatus": "In Review" }

// notion
{ "tracker": "notion", "database": "<database URL or id>", "statusProperty": "Status",
  "inProgressStatus": "In Progress", "inReviewStatus": "In Review" }

// in-repo
{ "tracker": "repo", "path": "docs/tickets", "filePattern": "NNN-slug.md" }
```

Do not guess status names — for Linear and Notion, list the real ones (`list_issue_statuses`, or the database's status property options) and record the exact strings. If a tracker's MCP tools are not connected, say so and ask the user to connect them rather than falling back to a different tracker.

When the user says the repo has switched trackers, rewrite the file instead of keeping both.

## 2. Understand the ticket

Fetch the ticket using the resolved tracker:

| Tracker | Fetch | Comments / discussion | Attachments |
| --- | --- | --- | --- |
| `linear` | `get_issue` | `list_comments` | `extract_images` |
| `notion` | `notion-fetch` on the page (or `notion-query-data-sources` on the database to find it by title/id) | `notion-get-comments` | image blocks in the page body |
| `repo` | read `<path>/<id>*.md` | git history on that file (`git log -p`) | linked files in the repo |

Load MCP tools via ToolSearch if they are deferred.

- Acceptance criteria and design decisions often live in the comments, not the description — read them.
- If the ticket has sub-issues, a parent, or dependencies on other tickets, read enough of them to understand scope. Implement only what this ticket asks for — do not expand into sibling tickets.
- Note anything ambiguous that would change the implementation (not cosmetic details) — you will resolve these in the grilling step, not by guessing now.

## 3. Explore before writing

- Check `git status` and the current branch first. If the working tree has unrelated uncommitted changes, tell the user before proceeding. If on the default branch, create a feature branch named after the ticket (e.g. `feat/abc-123-short-description`) following whatever branch-naming convention the repo's history shows.
- Read the parts of the codebase the ticket touches. Identify the existing patterns: component structure, styling approach, state management, naming conventions, how similar features are already built.
- Follow the codebase's structure — extend existing patterns rather than introducing new ones. If a project `CLAUDE.md` or contributing docs exist, follow them.

## 4. Grill the plan before writing code

Do not start implementing straight from the ticket. First sketch the approach you intend to take (files you will touch, the shape of the change, and the open questions from step 2), then invoke the `grill-with-docs` skill with the Skill tool to stress-test it with the user. (It ships with the `mattpocock-skills` plugin, which `adora` depends on; if it is not installed, fall back to interviewing the user one question at a time, always offering your recommended answer.)

- Feed the grilling session your proposed approach plus the ticket's acceptance criteria, so it interviews against a concrete plan rather than a blank page.
- Let the session run to its conclusion — it also records ADRs and glossary entries, which are part of the ticket's output.
- Carry the decisions that come out of it into the implementation. If grilling changes the scope or the approach, use the revised version, not your original sketch.
- Skip this step only if the user explicitly says to skip the grilling (e.g. "no grilling", "just implement it").

## 5. Implement

- Make the changes, matching the surrounding code's style, idioms, and comment density.
- Prefer the smallest change that fully satisfies the ticket. No drive-by refactors.
- Reuse existing components, utilities, and design tokens instead of duplicating them.

## 6. Test and guard against regressions

- Write tests where the codebase has testing infrastructure: follow its existing test patterns, runner, and file locations. Cover the new behavior and relevant edge cases. In a React Native project use the `write-tests` skill. If the repo has no test setup, say so instead of inventing one.
- Run the full relevant test suite (not just your new tests), plus lint and typecheck/build if the repo has them. Fix any failures your change caused. `validate-change` covers which checks match which change scope and how to avoid blaming pre-existing failures on your diff.
- Check for backwards regressions: search for other usages of anything you changed (components, props, exported functions, styles) and confirm they still work. Use `verify` to exercise the change end-to-end on a simulator when the behavior is runtime-only.

## 7. Hand off

Move the ticket to the configured `inReviewStatus`:

| Tracker | How |
| --- | --- |
| `linear` | `save_issue` with the new state (confirm exact names with `list_issue_statuses`) |
| `notion` | `notion-update-page` setting the configured `statusProperty` |
| `repo` | edit the ticket file's `**Status:**` line to `In Review · <date>`, per that file's existing convention |

- Add a brief note on the ticket summarizing what was implemented — a comment for Linear/Notion, an appended section for an in-repo ticket — only if the user has asked for that in the past or the change deviates from the ticket.
- Summarize for the user: what changed (files + behavior), what tests were added, what was verified, and any assumptions made.
- Ask the user if they want you to create a commit. Do not commit or push without their confirmation. If you created `.claude/ticket-tracker.json` this session, include it.

## Danger zone

- **Never hardcode a tracker.** Everything tracker-specific comes from `.claude/ticket-tracker.json`. If the file is missing, ask — do not assume Linear.
- **Never invent status names.** Read them from the tracker; a `save_issue` with a made-up state silently no-ops or errors.
- **Never write the config from a guess.** The detection heuristics in step 1 produce a *recommendation* for the user to confirm, not an answer.
- Ticket ID formats differ (`ABC-123`, a Notion page title or URL, `007`). Resolve the argument against the configured tracker rather than pattern-matching it.

`ticket-shaping` is the counterpart that writes tickets into the same tracker, and reads the same config file.
