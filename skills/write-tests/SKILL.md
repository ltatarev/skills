---
name: write-tests
description: >
  Writes Jest unit tests the house way in a React Native repo. Use when the user
  asks to add or write tests, says "test this", or after changing merge logic,
  persist transforms, sync, eligibility rules, verification, ordering, or utility
  logic. Covers detecting the repo's unit Jest config, what its setup file mocks,
  the fixture-builder test style, how to run one focused file, and what does or
  does not deserve a test.
---

# Writing unit tests

Unit tests in these projects are **pure-logic tests**: node environment, a
minimal mocked `react-native`, no renderer. The standard: test non-trivial
business logic (merge, persist, sync, eligibility, verification, ordering,
edge-case utils) with small fixture builders; never write trivial
assertion-only tests.

## Step 1 — read the repo's test setup before writing anything

Never assume the config. These repos commonly have **two** Jest configs and
only one of them is the real unit-test path.

1. Read `package.json` scripts. Look for a dedicated unit script (often
   `test:unit`) pointing at its own config (often `jest.unit.config.js`).
   A bare `test` script using the `react-native` preset is usually *not* where
   the tests live — check which config the existing tests actually match.
2. Read that config and note:
   - `testEnvironment` — typically `node`, meaning no jsdom and no native runtime.
   - **`testMatch`** — this is the trap. If it is `['**/*.test.ts']`, a
     `.test.tsx` file is **silently skipped**. Component/JSX tests are then not
     supported at all, and naming a file `.test.tsx` ships an unrun test that
     looks green.
   - `setupFiles` — read the setup file and list what it mocks globally.
3. Read 2–3 existing test files near the code you are testing. Mirror their
   imports, fixture style, and naming exactly.

A typical setup file globally mocks: `__DEV__ = false`; `react-native` down to
just `{ NativeModules: {}, Platform }` with a working `Platform.select`; the
filesystem and config packages; and the app's logger and error service as
`jest.fn()`s you can assert against.

Anything else native (MMKV, iCloud, IAP, notifications) is usually **not**
mocked — mock it per-file with `jest.mock(...)` at the top, or better, test a
pure function that does not import it at all.

## Step 2 — commands

- One file: `yarn test:unit path/to/file.test.ts` (check the script name first).
- Whole unit suite: `yarn test:unit`.
- After changing imports or module boundaries: `yarn madge`.
- Finish with lint and typecheck.

Read the script definition before adding flags — options like `--watchman=false`
are often already baked in.

## Canonical style

Test files sit **next to** the source they test, named `<source>.test.ts`.

Plain-fixture style — behavior-named `it` strings, minimal literal objects:

```ts
import { pickNewerAsset } from './pickNewerAsset';

describe('pickNewerAsset', () => {
  it('returns cloud entity when cloud updatedAt is newer', () => {
    const local = { id: 'a1', caption: 'local', updatedAt: 100 };
    const cloud = { id: 'a1', caption: 'cloud', updatedAt: 200 };

    expect(pickNewerAsset(local, cloud, 0, 0)).toEqual(cloud);
  });

  it('prefers cloud caption when timestamps tie and local caption is empty', () => {
    const local = { id: 'a1', updatedAt: 1000 };
    const cloud = { id: 'a1', caption: 'from device A', updatedAt: 1000 };

    expect(pickNewerAsset(local, cloud, 0, 0)).toEqual(cloud);
  });
});
```

Builder style for state-shaped fixtures — module-level helpers with an
`overrides` parameter, matching the real entity-adapter shape `{ ids, entities }`
and importing the real slice names from the adapters rather than hardcoding them:

```ts
const OWNER_ID = 'user-1';

const buildAsset = (
  id: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> => ({
  id,
  ownerId: OWNER_ID,
  caption: `Asset ${id}`,
  isPublished: false,
  ...overrides,
});

const buildModule = (args: {
  items: string[];
  assets: Record<string, Record<string, unknown>>;
  lastUpdatedAt?: number;
}): Record<string, unknown> => ({
  [itemsSliceName]: {
    ids: [OWNER_ID],
    entities: { [OWNER_ID]: buildEntity(args.items, args.lastUpdatedAt ?? 1000) },
  },
  [assetsSliceName]: { ids: Object.keys(args.assets), entities: args.assets },
});
```

Conventions to copy: `describe` named after the function or module; `it` strings
that state observable behavior ("unions assets from both devices"), not
implementation; slice names imported from the real adapters; no snapshots.

## What deserves a test

Non-trivial business logic: merge rules, persist transforms, account teardown,
ordering, eligibility and gating rules, purchase/entitlement verification, and
utility functions with real edge cases.

Skip trivial assertion-only tests — getters, constant re-exports, "renders
without crashing". Components are usually not testable under a node-environment
unit config anyway.

If the repo has a `CONTEXT.md`, use its vocabulary in test names.

## Procedure: test-driving a change to high-risk logic

1. Read the relevant `CONTEXT.md` sections and any ADR covering the area first.
   Merge semantics in particular are usually per-field, not whole-state
   last-write-wins.
2. Run the existing tests for the area **before** changing code — they encode
   the current contract, and you need to know they were green.
3. Add failing cases for the new behavior to the existing test file. Extend its
   builders; do not invent a second fixture style in the same folder.
4. Implement, then re-run the focused file until green.
5. Run the neighboring suites — merge, persist, and sync interlock, so a change
   in one usually needs the others re-run.
6. Finish with lint and typecheck; `madge` if imports changed.

## Danger zone — never do

- Never name a unit test file `.test.tsx` when `testMatch` is `**/*.test.ts` —
  it is skipped and you ship an unrun test that looks green.
- Never import screen or component modules into a unit test — the mocked
  `react-native` has no components and the import throws at collection time.
- Never weaken an existing merge, persist, or sync assertion to make your change
  pass. Those tests are the data-integrity contract; a "fixed" test there means
  data loss or resurrected deleted records on real devices. Discuss instead.
- Never use `any` in fixtures — `Record<string, unknown>` is the house shape for
  loose objects.
- Never add snapshot tests — they rot and hide exactly the regressions these
  suites exist to catch.
- Never leave `it.only` in the diff.

## Definition of done

- [ ] Focused file passes.
- [ ] Related area suites pass (merge/persist/sync neighbors).
- [ ] Test names describe behavior in the project's domain vocabulary.
- [ ] No trivial assertion-only tests added.
- [ ] Lint and typecheck pass; `madge` if imports changed.
- [ ] If the change touched runtime UI too, consider `verify`; `gitmoji` if
      committing.
