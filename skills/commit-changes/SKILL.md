---
name: commit-changes
description: >
  Split the current working tree into a sequence of small, meaningful commits.
  Use when the user asks to commit their current changes, split a mixed diff,
  clean up a working tree before a PR, or create reviewable commits.
---

# Commit changes into meaningful commits

Create a sequence of reviewable commits with **one concern per commit**. Never
commit a mixed working tree as-is.

## Workflow

### 1. Inspect the working tree

Run:

```sh
git status --porcelain=v1
git diff --stat
git diff --staged --stat
git log --oneline -10
```

Read the full diff (including untracked files) before planning commits.

### 2. Respect staged changes

If the index already contains staged changes:

- Treat them as an intended first commit.
- Confirm before unstaging anything.
- If they are clearly the result of an accidental `git add .`, reset the index
  with `git reset` (never `--hard`).

### 3. Plan commit groups

Group by **concern**, not by directory.

Typical groups:

- One feature or bug across many files → one commit.
- Refactors, renames, extracted helpers → separate commit before behavior.
- Formatting or lint-only changes → separate commit.
- Dependency updates and lockfiles → with the change requiring them.
- Generated files → with the change that generated them.
- Tests → together with the code they verify.
- Mixed concerns in one file → split by hunk.

Aim for roughly **2–6 commits**.

Before making changes, show the planned commits with a one-line summary and the
affected files.

### 4. Stage each commit

Start from a clean index:

```sh
git reset
```

For each planned commit:

```sh
git add <paths>
git status --short
git commit -m "<message>"
```

Verify the staged files before every commit.

### 5. Split files by hunk when needed

If one file belongs to multiple commits:

```sh
git diff -- <file> > .git/split.patch
git apply --cached --check .git/split.patch
git apply --cached .git/split.patch
```

Edit the patch so it contains only the desired hunks. Remaining hunks stay in
the working tree for later commits.

For new files that need splitting:

```sh
git add -N <file>
```

### 6. Write commit messages

- Use the **gitmoji** skill.
- Match the repository's existing commit style.
- Each commit should describe a single concern. If the subject naturally needs
  "and", the split is probably wrong.

### 7. Verify

Run:

```sh
git status --short
```

Report:

- created commits
- remaining uncommitted changes and why they were left

## Never

- Use `git add -A` when splitting commits.
- Push.
- Rewrite existing history (`--amend`, `rebase`, `reset --hard`) unless the
  user explicitly requests it.
- Restore or discard files to solve grouping.
- Create a branch unless requested.
- Commit secrets, local configuration, debug code, or unrelated incidental
  changes without confirmation.

After each commit, re-run `git status` in case hooks introduced additional
changes.

Run project validation once after all commits are complete, not after every
commit.

## Done

- Every commit represents one concern.
- Commits are ordered so prerequisites come first.
- Messages follow gitmoji and repository style.
- Remaining changes are reported.
- Nothing was pushed or history rewritten.
