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

## Token budget

- Batch git commands into one shell call. Do not run one command per call.
- Read each diff one time. Do not read a diff again after you plan.
- Load the **gitmoji** skill one time per run, not one time per commit.
- Do not read lockfiles, generated files, snapshots, or binaries. The stat line
  is sufficient to group them.

## Workflow

### 1. Inspect the working tree

Run one call:

```sh
git status --porcelain=v1; git diff --staged --stat; git diff --stat; git log --oneline -8
```

Then read the diff in one call. Exclude the files that you do not read:

```sh
git diff -- . ':!*.lock' ':!package-lock.json' ':!*.snap' ':!*.pbxproj'
```

For untracked files, read only text files that are small. For a large
untracked file, read the first 40 lines.

If the diff is more than approximately 1500 lines, read it one file at a time.
Use `git diff --stat` to select the order.

### 2. Respect staged changes

If the index already contains staged changes:

- Treat them as an intended first commit.
- Confirm before you unstage anything.
- If they clearly come from an accidental `git add .`, reset the index with
  `git reset` (never `--hard`).

### 3. Plan commit groups

Group by **concern**, not by directory.

- One feature or bug across many files → one commit.
- Refactors, renames, extracted helpers → a separate commit before behavior.
- Formatting or lint-only changes → a separate commit.
- Dependency updates and lockfiles → with the change that needs them.
- Generated files → with the change that generated them.
- Tests → with the code that they verify.
- Mixed concerns in one file → split by hunk.

Aim for approximately **2–6 commits**.

Show the plan as one line per commit: the subject and the files. Then continue.
Wait for the user only if two groupings give very different results.

### 4. Make the commits

Start from a clean index with `git reset`.

Make each commit in one shell call. Use a heredoc for the message:

```sh
git add <paths> && git diff --cached --stat && git commit -q -F - <<'EOF' && git status --short
<message>
EOF
```

If no commit needs a hunk split, put all the commits in one call.

The `git status --short` at the end shows changes from hooks. If a hook
changes files, add those changes to the plan.

### 5. Split files by hunk when necessary

If one file belongs to more than one commit, write only the wanted hunks to a
patch file. Copy the hunks from the diff that you already read. Do not read the
full file diff to a patch and then edit it.

```sh
cat > .git/split.patch <<'EOF'
<file header and wanted hunks>
EOF
git apply --cached --check .git/split.patch && git apply --cached .git/split.patch
```

The other hunks stay in the working tree for later commits.

For a new file that needs a split, run `git add -N <file>` first.

### 6. Write commit messages

- Use the **gitmoji** skill.
- Match the existing commit style from the `git log` in step 1.
- Write one concern per commit. If the subject needs "and", the split is
  probably wrong.

### 7. Verify and report

Run project validation one time after all commits, not after each commit.

Report in a short list:

- the commits that you created (`git log --oneline -<n>`)
- the remaining uncommitted changes and why you left them

## Never

- Use `git add -A` when you split commits.
- Push.
- Rewrite existing history (`--amend`, `rebase`, `reset --hard`) unless the
  user explicitly requests it.
- Restore or discard files to solve grouping.
- Create a branch unless requested.
- Commit secrets, local configuration, debug code, or unrelated incidental
  changes without confirmation.

## Done

- Every commit represents one concern.
- Prerequisites come first in the commit order.
- Messages follow gitmoji and the repository style.
- Remaining changes are reported.
- Nothing was pushed and no history was rewritten.
