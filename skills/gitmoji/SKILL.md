---
name: gitmoji
description: >-
  Gitmoji commit message format for git commits. Use when the user asks to
  commit changes, push code, create a commit message, or invokes /git-commit,
  /git-commit-push, or /git-commit-push-pr.
---

# Gitmoji Commit Conventions

This skill defines the commit message format to follow when creating git commits.

## When to use this skill

- User asks to "commit my changes" or "create a commit"
- User asks to "push my code" or "commit and push"
- User invokes /git-commit, /git-commit-push, or /git-commit-push-pr commands
- Any task involving creating a git commit message

## Commit format

1. First line: Gitmoji + short description (< 50 chars)
2. Blank line
3. Detailed description listing significant changes
4. Write concisely using an informal tone
5. Do not use specific names or files from the code
6. Do not use phrases like "this commit", "this change", etc.
7. If branch contains a ticket reference (e.g. `JIRA-123`, `PROJ-456`), add it as a footer: `Refs: JIRA-123`

## Choosing a gitmoji

**Read [references/gitmoji.json](references/gitmoji.json) before writing the commit message.**

That file is the canonical list of gitmojis for this skill. Each entry has:

| Field | Use |
| :---- | :-- |
| `emoji` | Put this character at the start of the first line |
| `code` | Short name (e.g. `:sparkles:`) — do not use in the commit message |
| `description` | **Primary field** — match the change type to pick the right emoji |
| `name` | Alternate keyword for search (e.g. `sparkles`, `bug`) |
| `semver` | Optional hint for version bumps — ignore unless the user asks |

### Selection workflow

1. Read the staged diff and summarize the change type.
2. Open `references/gitmoji.json` and scan `description` values for the best match.
3. If several fit, prefer the most specific one (e.g. `:ambulance:` over `:bug:` for a critical hotfix).
4. Use the matched entry's `emoji` on the first line — not the `:code:` text.

Do not rely on memory or the table below; always confirm against the JSON file.

## Example

Branch: `feature/JIRA-123-auth`

```md
✨ Add user authentication

- Implement OAuth2 flow
- Add session management
- Handle token refresh

Refs: JIRA-123
```
