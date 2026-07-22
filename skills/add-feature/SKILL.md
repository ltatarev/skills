---
name: add-feature
description: >
  Scaffolds a new feature module under src/modules/ or extends an existing one
  in a package-by-feature React Native codebase. Use when the user asks to add a
  feature, screen, module, setting, Redux slice, selector, or thunk; wire a new
  route into React Navigation; register a reducer in the store; or extend an
  existing module. Also use when deciding where new code belongs (module vs
  utils vs theme) or when a change crosses module boundaries.
---

# Adding or Extending a Feature Module

Scaffolding a new `src/modules/<name>/` module and extending existing ones: the
file anatomy, the typed thunk pattern, store registration, persistence
consequences, navigation wiring, and module boundary rules. The standard: a new
module must look indistinguishable from the smallest existing one, and nothing
may import module internals from outside.

## Ground yourself first

Read the repo before scaffolding — module conventions drift between projects.

1. `ls src/modules/` and pick the **smallest module that already has Redux**.
   That is your template; copy its shape rather than this skill's.
2. Read `AGENTS.md` / `CLAUDE.md` for the conventions and non-negotiables.
3. Read `CONTEXT.md` if present for the domain vocabulary — use its terms
   exactly, and the `domain-modeling` skill if you are introducing new ones.
4. Read the root store file to see how reducers are registered and what the
   persist config actually persists.

## Anatomy of a module

```text
src/modules/<name>/
├── const.ts          # MODULE_NAME (the Redux slice key + route prefix)
├── types.ts          # module-owned types
├── index.ts          # public barrel — the ONLY cross-module import surface
└── redux/
    ├── slice.ts      # createSlice; exports <name>Actions, <name>Reducer
    ├── selectors.ts  # plain functions over RootState
    ├── thunks.ts     # createAppAsyncThunk wrappers
    ├── utils.ts      # slice-local helpers
    └── index.ts      # re-exports slice/selectors/thunks for the barrel
```

Modules with UI add `screens/`, `components/`, `fragments/`, `hooks/`, and a
`navigator.tsx`. Each subfolder gets its own `index.ts`. Files inside a module
use relative imports; only the module's `index.ts` is the public surface.

`const.ts` is minimal and load-bearing — the slice key and route names derive
from it:

```typescript
export const MODULE_NAME = 'settings';

export const ROUTES = {
  SETTINGS: `${MODULE_NAME}/settings`,
  CUSTOMIZE_THEME: `${MODULE_NAME}/customize-theme`,
} as const;

export type StackParamList = {
  [ROUTES.SETTINGS]: undefined;
  [ROUTES.WEBVIEW]: { url: string; title: string };
  // one entry per route; params typed here, not inline
};
```

A minimal slice:

```typescript
import { createSlice } from '@reduxjs/toolkit';
import { isDeleteAccountAction } from 'utils/redux';
import { MODULE_NAME } from '../const';

const INITIAL_STATE: SliceState = { isOnboardingComplete: false };

export const onboardingSlice = createSlice({
  name: MODULE_NAME,
  initialState: INITIAL_STATE,
  reducers: {
    setOnboardingFinished: state => {
      state.isOnboardingComplete = true;
      return state;
    },
  },
  extraReducers: builder => {
    builder.addMatcher(isDeleteAccountAction, () => INITIAL_STATE);
  },
});

export const onboardingActions = onboardingSlice.actions;
export const onboardingReducer = onboardingSlice.reducer;
```

## The typed thunk pattern

The root redux module exports an `AppAsyncThunkConfig`:

```typescript
export type AppAsyncThunkConfig = {
  state: RootState;
  dispatch: AppDispatch;
  extra?: null;
  rejectValue?: string;
};
```

Every thunks file creates its own local helper:

```typescript
import { createAsyncThunk } from '@reduxjs/toolkit';
import type { AppAsyncThunkConfig } from 'modules/redux';
import { MODULE_NAME } from '../const';

const createAppAsyncThunk = createAsyncThunk.withTypes<AppAsyncThunkConfig>();

export const fetchItems = createAppAsyncThunk(
  `${MODULE_NAME}/fetchItems`,
  async (_, thunkApi) => {
    const state = thunkApi.getState(); // fully typed RootState
    // ...
    throw new Error('No user found'); // throw => rejected action for the UI
  },
);
```

Action type strings are always `` `${MODULE_NAME}/<verb>` ``. Thunks throw when
the UI needs a rejected action.

## Registering a slice in the store

Add the reducer to `rootReducer` in the store file — that file is a deliberate
exception to the barrel-only rule and imports at slice depth:

```typescript
import { MODULE_NAME as API } from 'modules/api/const';
import { apiReducer } from 'modules/api/redux';

export const rootReducer = combineReducers({
  [FEED]: feedReducer,
  [API]: apiReducer,
});
```

**Read the persist config before adding a slice.** In these projects it
typically persists the *whole* root with no whitelist, which means:

- Any slice you add to `rootReducer` is persisted automatically.
- If the slice holds large or device-local data (base64 blobs, `file://` paths),
  that is a problem — look for the existing transform that strips such data
  before persist and add yours to it. Device-local paths must never reach cloud
  backup; they are meaningless on another device.
- If the project syncs state across devices, find the module-key list that drives
  the merge (grep the sync module for something like `PERSIST_MODULE_KEYS`). A
  slice key missing from that list is silently skipped by the merge — the bug is
  invisible locally and shows up only as data loss after a two-device sync.

Always reference `MODULE_NAME` rather than string literals — slice keys do not
always match the folder name (a `user` module may own the `'users'` key).

## Account reset and teardown (do not skip)

Any slice holding per-account or user-derived data must react to the app's
shared reset actions in `extraReducers` — conventionally exported from
`utils/redux` as matchers:

- A "delete all data" action → reset to initial state. Every existing slice
  should already do this; copy the pattern.
- A "remove one account" action → drop that account's entities. The payload
  carries the ids. Never write per-account teardown in a settings screen or
  loop over entities manually.

If the slice must react to a cross-module flow, use the matchers that flow's
module exports. Never re-declare another module's action type strings.

## Wiring a screen into navigation

1. Add the route to the module's `const.ts` `ROUTES` and `StackParamList`.
2. Add a `<Stack.Screen>` in the module's `navigator.tsx`:

   ```typescript
   const Stack = createNativeStackNavigator<StackParamList>();

   export function Navigator() {
     return (
       <Stack.Navigator screenOptions={HIDE_HEADER_OPTIONS}>
         <Stack.Screen component={SettingsScreen} name={ROUTES.SETTINGS} />
       </Stack.Navigator>
     );
   }
   ```

3. Export it from the barrel, aliased:
   `export { Navigator as SettingsNavigator } from './navigator';`
4. Mount a whole new module's navigator in the parent navigator (the tab shell,
   or the root stack for pre-onboarding flows).
5. Cross-module navigation: navigate by route string. If importing the target
   module's barrel would create a cycle, mirror the route constant in the shared
   navigation types instead — that is what those shared constants are for. Run
   `madge` afterwards.
6. Screen tracking goes through the app's analytics hook; never import the
   analytics or crash-reporting SDK directly in feature code.

## Module boundaries

Feature code imports other modules only through `modules/<name>` — the barrel.
ESLint `no-restricted-imports` enforces it. Check `eslint.config.mjs` for the
repo's list of allowed deep-import exceptions (typically redux and orchestration
folders, the store, and sync/persist internals, all to avoid circular barrels).

If a module needs to expose something new, add it to that module's `index.ts`.
Never widen the ESLint exceptions instead.

## Checklist: new module

1. Read `CONTEXT.md` for the domain area; use its vocabulary exactly.
2. Create `src/modules/<name>/{const.ts,types.ts,index.ts}`; `MODULE_NAME` first.
3. Add `redux/` (slice, selectors, thunks, index) if the feature owns state;
   include the reset/teardown matchers from day one.
4. Register the reducer in the store; decide the persistence and sync story.
5. Add `screens/` + `navigator.tsx`, mount it in the parent navigator.
6. Add copy to the i18n catalog; use `useTranslation`, including a11y labels.
7. Styles via `StyleSheet` from `react-native-unistyles`, theme tokens only;
   shared UI goes to `theme/ui`, not the module. See `build-ui`.
8. Tests for non-trivial logic, colocated with the source. See `write-tests`.

## Checklist: extending an existing module

1. Put the code in the matching subfolder (hook in `hooks/`, screen in
   `screens/`, selector in `redux/selectors.ts`).
2. New cross-module exports go through the module's `index.ts` only.
3. New route → `const.ts` `ROUTES` + `StackParamList` + `navigator.tsx`.
4. New thunk → the module's `redux/thunks.ts`, via the local `createAppAsyncThunk`.
5. New user-facing copy → the i18n catalog.
6. Feature gate if the repo has a feature-flag module.

## Danger zone / never do

- Never import `modules/<name>/<internal>` from screens, hooks, or utils — lint
  error, and it creates the circular-dependency knots `madge` exists to catch.
- Never hard-code slice or persist keys — literals silently break persist and
  merge. Reference the module's constants and persist-shape helpers.
- Never add a synced slice without updating the sync module-key list.
- Never store `file://` paths or large base64 in a persisted slice without a
  transform.
- Never skip the reset matchers — "delete all data" would leave your slice's
  stale data behind.
- Do not introduce RTK Query, AsyncStorage, TS `enum`, or `@/` path aliases —
  these are out of scope for this house style.

## Definition of done

- Lint and typecheck pass.
- `madge` passes if you touched imports, barrels, or navigation.
- Focused tests pass for any non-trivial logic added.
- `verify` for runtime confirmation of UI changes; `gitmoji` if committing.
