---
name: commit-changes
description: >
  Split a messy working tree into a series of small, meaningful commits. Use
  when the user says "commit current changes into meaningful commits", "commit
  my changes", "split this into commits", "clean up my working tree before a
  PR", or when a session touched several unrelated concerns at once and the
  diff needs separating before review. Covers grouping the diff by concern,
  ordering commits so each one stands alone, path- and hunk-level staging
  without interactive `git add -p`, and what to never sweep into a commit.
---

# Commit changes into meaningful commits

The job: take whatever is in the working tree right now and land it as a
sequence of commits a reviewer can read one at a time. **One concern per
commit.** Never `git add -A && git commit` a mixed tree — that destroys the
only cheap chance to make the change reviewable.

## Procedure

### 1. Survey before touching the index

```sh
git status --porcelain=v1
git diff --stat            # unstaged
git diff --staged --stat   # already staged — see step 2
git log --oneline -10      # message style actually used in this repo
```

Then read the **full** diff, not just the stat. Grouping decisions need the
hunks, not the filenames — two edits in one file often belong to two commits,
and edits in ten files often belong to one.

For untracked files, `git status --porcelain` lists them but `git diff` does
not. Read each one before deciding it belongs anywhere.

### 2. Respect a pre-existing index

If `git diff --staged` is non-empty at the start, the user staged that
deliberately. Treat it as the intended first commit and confirm before
unstaging anything. If it is clearly just a leftover `git add .`, say so and
reset it with `git reset` (no `--hard`, ever).

### 3. Group the diff by concern

A commit is a concern, not a directory. Assign every hunk to exactly one group:

| Signal | Grouping |
| --- | --- |
| Same feature / bug across many files | One commit, however wide it spreads |
| Refactor or rename touching a feature file | Separate commit, **before** the feature |
| Formatting or lint-only churn | Its own commit, kept out of logic commits |
| Dependency + lockfile | With the change that needs it, or alone if speculative |
| Generated output (build artifacts, snapshots, native project files) | With the change that regenerates it |
| Test + the code it covers | Together — a test that does not compile alone is not a standalone commit |
| Two edits in one file serving different concerns | Split at hunk level (step 5) |

Order the groups so each commit is coherent on its own: mechanical
prerequisites (renames, moves, extracted helpers, new dependencies) first, then
behavior, then tests and docs that describe it. Aim for 2–6 commits; if the plan
has more than ~8, the grouping is too fine — merge the ones a reviewer would
read together.

**Show the plan before executing it** — a one-line summary per planned commit
with its files. That is the cheapest point for the user to correct grouping.

### 4. Stage by path when the split is clean

```sh
git reset                       # start from an empty index
git add <paths for group 1>
git status --short              # verify: only group 1 is staged
git commit -m "$(cat <<'EOF'
<message>
EOF
)"
```

Repeat per group. Verify the index **before every commit** — the most common
failure is a stray file riding along in the wrong commit.

### 5. Stage by hunk when one file spans two concerns

`git add -p` is interactive and unavailable here. Use a patch file instead:

```sh
git diff -- <file> > .git/split.patch   # then edit it down to the wanted hunks
git apply --cached .git/split.patch     # stages only those hunks
```

Editing the patch means deleting unwanted `@@` hunk blocks whole. If you change
the number of context or `+`/`-` lines inside a hunk, its `@@ -a,b +c,d @@`
counts must be updated to match or `git apply` rejects the patch. Check with
`git apply --cached --check` first, and keep the leftover for the next commit —
it stays in the working tree automatically.

For a new file that should be split, stage it whole with `git add -N <file>`
first so `git diff` produces hunks for it.

### 6. Write the messages

Message format comes from **`gitmoji`** — read that skill and pick the emoji
from its `references/gitmoji.json`. Match the tense and structure of
`git log --oneline -10` if this repo diverges from it.

Each message describes what that commit alone does. If the subject needs an
"and", the split is wrong — go back to step 3.

### 7. Verify the result

```sh
git log --oneline <base>..HEAD
git status --short          # what deliberately stayed behind
git diff <base> --stat      # must equal the original working-tree diff
```

The sum of the commits must equal what was there at the start, minus anything
intentionally left uncommitted. Report the commit list and name anything still
dirty and why.

## What never gets swept in

- **Secrets and local config** — `.env*`, credentials, keystores, `*.p12`,
  personal editor settings. Leave them, and say they were left.
- **Debug leftovers** — `console.log`, commented-out code, `.only` on a test,
  temporary instrumentation. Flag them to the user rather than committing them;
  they are almost always accidental.
- **Unrelated files a tool touched** — a lockfile bumped by an incidental
  install, an IDE-reformatted file nobody asked for. Ask before including.
- **Anything the user has not seen.** If a group contains a file you cannot
  explain the presence of, ask instead of guessing.

## Danger zone

- **Never `git add -A` across the whole tree** when the point of the task is
  splitting it up.
- **Never push.** This skill ends at the last commit. Push and PR only on an
  explicit ask.
- **Never rewrite existing history** — no `commit --amend`, `rebase`, or
  `reset --hard` on work that was already committed before this task, unless
  the user asks for exactly that.
- **Never `git checkout`/`restore` a file to resolve a grouping problem** —
  that deletes the user's work. Leave it unstaged instead.
- **Do not create a branch on your own initiative**; if the repo is on its
  default branch and this looks like feature work, say so and let the user
  decide.
- **Re-check `git status` after each commit** — a pre-commit hook may have
  reformatted files, leaving new unstaged changes that belong to the commit
  that just happened.
- **Verify checks pass once at the end**, not per commit. Validating each
  commit in isolation means stashing the rest and is rarely worth it — if the
  user wants every commit green, tell them that cost up front.

## Definition of done

- [ ] Every commit is one concern, with a subject that needs no "and".
- [ ] Commits are ordered so prerequisites land before what depends on them.
- [ ] `git diff <base> --stat` matches the original tree, minus deliberate
      exclusions.
- [ ] Messages follow `gitmoji` and the repo's existing log style.
- [ ] Nothing was pushed; no pre-existing history was rewritten.
- [ ] Anything left uncommitted was reported, with the reason.
