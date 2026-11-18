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

**Read [references/gitmoji.tsv](references/gitmoji.tsv) one time per session.**
Do not read it again for each commit.

The file has one line per gitmoji: the emoji, a tab, and the description.
It comes from `references/gitmoji.json`, the canonical list. Read the JSON only
if you need the `code`, `name`, or `semver` field.

### Selection workflow

1. Use the diff that you already read to find the change type.
2. Find the best match in the `description` column.
3. If several fit, use the most specific one (for example 🚑️ over 🐛 for a critical hotfix).
4. Put the emoji on the first line, not the `:code:` text.

Do not rely on memory. Confirm the emoji against the list.

If `gitmoji.json` changes, regenerate the list:

```sh
python3 -c "import json;print('# Generated from gitmoji.json. One gitmoji per line: emoji, then description.');[print(g['emoji']+'\t'+g['description']) for g in json.load(open('gitmoji.json'))['gitmojis']]" > gitmoji.tsv
```

## Splitting a mixed working tree

This skill covers the message only. When the working tree holds several
unrelated concerns and needs to become more than one commit, follow
`commit-changes` for the grouping and staging procedure and come back here for
each message.

## Example

Branch: `feature/JIRA-123-auth`

```md
✨ Add user authentication

- Implement OAuth2 flow
- Add session management
- Handle token refresh

Refs: JIRA-123
```
