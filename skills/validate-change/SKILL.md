---
name: validate-change
description: >
  Validation and handoff procedure for React Native changes. Use when finishing
  any code change, before committing or handing off, when the user says "run the
  checks", "is this ready", "validate", or asks whether tests/lint/types pass.
  Covers which checks match which change scope, how to establish a baseline so
  pre-existing issues are not blamed on new work, and the handoff report format.
---

# Validating a change before handoff

Which checks to run for a given change scope, and how to report them. The
standard: **every handoff names the checks that ran, their results, and which
were skipped and why.**

## Procedure

1. Read `package.json` scripts to learn this repo's actual command names — do
   not assume. Map them onto the check kinds in the table below.
2. Classify the change scope and pick the check set.
3. Run the checks. Establish a baseline before blaming yourself (see below).
4. If you added or changed business logic, add or update a colocated test and
   run it focused. See `write-tests`.
5. Write the handoff report. If committing, use `gitmoji`. For nontrivial
   runtime behavior, use `verify`.

## Which checks for which scope

| Change scope | Run | Skip |
| --- | --- | --- |
| Pure logic in `.ts` (merge, persist, utils, redux logic) | focused unit test for the touched files, then typecheck | circular-dep check, lint --fix |
| UI, components, screens (`.tsx`) | typecheck, lint | unit tests, unless logic was extracted into a `.ts` — most unit configs only match `*.test.ts` |
| Any change to imports, barrels (`index.ts`), or module boundaries | add the circular-dependency check (`madge`) to the above | |
| Broad refactor across modules | the repo's combined script — but read the caveat below | |
| Docs or comments only | lint on the touched scope | typecheck, madge, tests |

Always finish with lint passing (exit 0) before handoff.

Watch for a **bare `test` script that is not the unit-test path.** These repos
often have two Jest configs; run the one the existing tests actually match.

## Establish a baseline — do not fix what you did not break

Before treating a failure as yours:

```bash
git stash && <the failing check> ; git stash pop
```

If it fails identically without your change, it is pre-existing. Then:

- **Do not fix it** inside a feature diff — it bloats review and breaks the
  tightly-scoped-diff rule.
- **Do not report it** as caused by your change. Mention it as pre-existing.

Anything that appears only *with* your change is yours, no exceptions.

If the repo records baselines in its own docs (a known-warnings list, a
"typecheck is currently clean" note), read it — but re-verify rather than
trusting a stale date. A recorded baseline that has since been fixed will make
you ship real errors.

## Combined "sanity" scripts — read before running

A combined script is often defined as `lint --fix; typecheck; madge`, chained
with semicolons so later steps run even when earlier ones fail. Two consequences:

- **Read the full output.** Do not trust the final exit code alone.
- **`lint --fix` edits files.** Run it only when you intend formatting and
  import-order changes to land in your diff, and review `git diff` afterwards
  for files it touched outside your change.

## When native runs are justified

Prefer static checks and focused Jest. Build and run on a device or simulator
only when the task genuinely needs runtime verification: native module or config
changes, provider/app-shell changes, widget or IAP behavior, gesture or worklet
behavior, or when the user asks for a visual check. Use `verify` to drive the
app. Otherwise state in the handoff that native runs were skipped and why.

## Handoff report format

End every handoff with a checks section:

```text
Checks:
- yarn test:unit src/modules/feed/merge/mergeFeedPersistModule.test.ts — pass (12 tests)
- yarn tsc — pass (baseline: clean)
- yarn lint — pass (1 pre-existing warning in FollowBackInsightScreen.tsx, untouched)
- yarn madge — skipped (no import/boundary changes)
- native run — skipped (no runtime-only behavior changed)
```

Every line is either a result or an explicit skip reason. A check you did not
run and did not mention reads as a check that passed.

## Never do

- Never claim a check passed without running it.
- Never fix baseline lint warnings or unrelated issues inside a feature diff.
- Never run a combined `--fix` script and hand off without reviewing what it
  edited.
- Never write a `.test.tsx` unit test expecting a `**/*.test.ts` config to run
  it — the test silently never runs.
- Never skip the circular-dependency check after touching barrels or
  cross-module imports — barrel cycles surface only there, not in typecheck.

## Definition of done

- [ ] Check set matches the change scope.
- [ ] Focused unit tests pass for touched business logic; new logic has tests.
- [ ] Typecheck clean; lint exit 0 with no NEW warnings.
- [ ] Circular-dependency check run if imports or barrels changed.
- [ ] No baseline issues "fixed" incidentally; diff is tightly scoped.
- [ ] Handoff report lists every check with a result or a skip reason.
