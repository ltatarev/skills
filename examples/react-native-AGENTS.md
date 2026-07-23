# Agent Instructions — example

> **This is a reference file, not this repo's own agent instructions.** Copy it
> to your project root as `AGENTS.md` (and/or `CLAUDE.md`) and edit the
> specifics — paths, scripts, and rules that differ in your codebase.
>
> It documents the conventions of
> [`ltatarev/react-native-template`](https://github.com/ltatarev/react-native-template),
> which the React Native skills in this repo assume. Project rules and skill
> procedures work best together: this file says what the codebase is, the
> skills say how to work in it.
>
> Everything below is written as if it already lives in your project.

---

Purpose: keep AI coding assistants aligned with this React Native codebase.
Prefer these project conventions over generic React Native advice. For the
architecture vocabulary, read `CONTEXT.md`. For recurring setup and build
problems, read `troubleshooting.md`.

**The repo is the source of truth.** Where this file and the code disagree, the
code wins and this file is the bug. `package.json`, `tsconfig.json`,
`babel.config.js`, `eslint.config.mjs`, and `jest.unit.config.js` are
authoritative for versions, aliases, lint rules, and test matching — read them
before assuming.

## Project Snapshot

- Framework: React Native 0.86 with React 19 (exact versions in `package.json`).
- Language: TypeScript with `strict: true`.
- Runtime/tooling: Node >= 22.11, Yarn 4 pinned via `packageManager`.
- Styling: `react-native-unistyles` v3.
- State: Redux Toolkit with typed hooks from `modules/redux`.
- Navigation: React Navigation native stack only.
- Internationalization: `react-i18next`, resources under `i18n/`.
- Persistence: redux-persist backed by MMKV through `utils/storage`.
- Unit tests: Jest, `node` environment, pure logic only.
- Common pure helpers: `src/common`.
- Feature flags: `modules/feature-flag`.
- Native/external capabilities: wrap them in `utils/*` adapters.

## Commands

Run everything from the project root (the directory holding `package.json`).

| Command | Use it for |
| --- | --- |
| `yarn lint` | Style, import order, module boundaries, React Native rules |
| `yarn tsc` | Typecheck (`--noEmit`) |
| `yarn test:unit [path]` | Unit tests; pass a path to run one file |
| `yarn madge` | Circular dependency check |
| `yarn sanity` | Lint + typecheck + madge, non-mutating |
| `yarn sanity:fix` | Same, but `lint --fix` first — **edits files** |
| `yarn pod-install` | After changing native dependencies |
| `yarn ios` / `yarn android` | Native runs; only when a task needs runtime verification |

Use focused checks while working and broader checks before handoff. Avoid
native app targets unless the task genuinely needs simulator or device runtime
verification.

`sanity` chains its steps with `;`, so later steps run even when earlier ones
fail — read the whole output, not just the exit code. After `sanity:fix`,
review `git diff` for files it touched outside your change.

## Path Aliases

Aliases are declared in **both** `tsconfig.json` (types) and `babel.config.js`
(runtime). Adding one means editing both, or imports resolve in the editor and
crash at runtime.

| Alias       | Resolves to     |
| ----------- | --------------- |
| `assets/*`  | `src/assets/*`  |
| `common/*`  | `src/common/*`  |
| `modules/*` | `src/modules/*` |
| `theme/*`   | `src/theme/*`   |
| `utils/*`   | `src/utils/*`   |

Each also has a bare form (`modules` → `src/modules`). `i18n/` sits outside
`src/` and is not aliased. Do not introduce a new alias style such as `@/`.

## Architecture

The codebase is package-by-feature.

```text
src/
├── assets/      # Fonts, images, bootsplash output
├── common/      # Pure shared hooks and types (no Redux, navigation, or theme)
├── modules/
│   ├── feature-flag/ # Typed boolean gates
│   ├── home/         # Reference feature — copy its shape, replace it with real ones
│   ├── main/         # App shell: providers, root navigator, global hosts
│   ├── navigation/   # Route service, stack helpers, navigation hooks
│   └── redux/        # Root store, persistor, typed Redux hooks
├── theme/
│   ├── hooks/     # Theme-aware hooks
│   ├── providers/ # Theme initialization providers
│   ├── services/  # Theme setup and platform adapters
│   ├── ui/        # Shared UI primitives (Text, View, Touchable, Toast, StatusBar)
│   ├── gutter.ts
│   ├── styles.ts
│   ├── theme.ts   # The only place color literals live
│   ├── types.ts
│   └── unistyles.ts
├── types/       # Ambient declarations (e.g. svg.d.ts)
└── utils/
    ├── error-handling/
    ├── haptic-feedback/
    ├── hooks/
    ├── logger/
    ├── services/   # env, platform, redux matchers
    ├── storage/
    └── toast.tsx

i18n/
├── en_EN.json   # <locale>.json, one per language
├── index.ts
└── resources.ts
```

### Module Boundaries

- Feature code lives under `src/modules/<feature>`.
- Each module exposes its public API through `src/modules/<feature>/index.ts`.
- Cross-module imports use `modules/<name>` — the barrel, never a deep path.
- ESLint enforces this with `no-restricted-imports` on `modules/*/*`.
- `src/modules/redux/store.ts` is the one file exempted from that rule; it
  imports slices at depth to avoid a circular barrel. Do not widen the
  exemption — export what you need from the module's `index.ts` instead.
- Files inside a module import each other relatively.
- Run `yarn madge` after touching barrels, imports, or navigation. Barrel
  cycles surface there and nowhere else.

Common module subfolders:

- `screens/` for route-level components.
- `components/` for reusable module-local components.
- `fragments/` for larger screen sections that are not shared UI primitives.
- `hooks/` for module hooks.
- `redux/` for slices, selectors, thunks, and adapters.
- `utils/` for pure module helpers.
- `persist/`, `merge/`, `sync/`, or `orchestration/` only when the module owns
  that specialized behavior.

### Adding a module

1. `const.ts` first: `MODULE_NAME` is the Redux slice key and the route prefix.
   Derive `ROUTES` and `StackParamList` from it; never hardcode those strings
   elsewhere.
2. `redux/` (slice, selectors, thunks, index) if the module owns state.
3. Register the reducer in `src/modules/redux/store.ts`, keyed by the imported
   `MODULE_NAME`.
4. `navigator.tsx` if it owns routes; mount it in the parent navigator.
5. Export the public surface from `index.ts`.
6. Copy the shape of the smallest existing module that already has Redux rather
   than inventing a new one.

### State

- Root Redux setup lives in `src/modules/redux`; store and persistor are
  module-level singletons.
- Components use `useAppDispatch` and `useAppSelector` from `modules/redux`.
- Thunks use `createAsyncThunk.withTypes<AppAsyncThunkConfig>()` declared
  locally in the module's `redux/thunks.ts`; action strings are
  `` `${MODULE_NAME}/<verb>` ``.
- Feature slices and selectors stay inside their module, exported from the
  public surface when other modules need them.
- Feature flags live in `modules/feature-flag`; add flags in `const.ts` and
  read them through selectors.

### Persistence

The persist config keys the whole root with **no whitelist**, so every reducer
added to `rootReducer` is persisted automatically. Before adding one:

- Do not persist large blobs or device-local values (`file://` paths, base64).
  They are meaningless on another device and bloat storage — add a transform
  that strips them, or keep that state out of Redux.
- Slices holding per-account or user-derived data must handle teardown in
  `extraReducers`, so a "delete all data" flow leaves nothing behind. Declare
  the cross-module action with `createAction` from `utils/services/redux.ts`
  (it produces `@@<module>/<action>` types) and match on it — never re-declare
  another module's action strings.
- Document any new MMKV instance or key namespace in
  `src/utils/storage/README.md`.

### React And Hooks

- Use function declarations for React components.
- Initialize state with the right value in `useState`; do not call `setState`
  synchronously in a `useEffect` body.
- Clean up subscriptions and timers in effects.
- Include all values used by `useCallback` and `useMemo` dependency arrays.
- Use `React.memo`, `useMemo`, and `useCallback` when they protect real work or
  stable references; do not add them mechanically.
- Use `FlatList` for long lists, never `ScrollView` + `.map()`.

### React Native And Worklets

- Use `Platform.select` for small platform differences and platform-specific
  files (`.ios.tsx` / `.android.tsx`) for larger branches.
- When calling JS from a worklet, use `scheduleOnRN` from
  `react-native-worklets`.
- Do not use `runOnJS` from `react-native-reanimated`.
- Mark worklet callbacks with the `'worklet'` directive where required.
- Values read inside a worklet must be shared values, not refs.

### Styling And UI

- Import `StyleSheet` from `react-native-unistyles`, **never** from
  `react-native` — the latter silently bypasses theming.
- Write stylesheets as `StyleSheet.create(theme => ({ ... }))`; the static
  object form is fine when nothing reads the theme.
- Shared UI primitives live in `theme/ui`; feature screens import them from
  `theme/ui`, not from internal primitive files.
- Compose from those primitives (`Text`, `View`, `Touchable`) instead of raw
  React Native components. If a genuinely reusable, presentation-only primitive
  is missing, add it to `theme/ui` and its barrel — do not fork a local copy
  inside a module.
- Use theme tokens for colors, typography, spacing, radii, shadows, and z-index.
  No color literals outside `theme/theme.ts`.
- Dynamic prop-derived styles are acceptable when a value truly depends on
  runtime data; static layout belongs in `StyleSheet.create`.
- Do not use single-element style arrays.
- SVGs import as components via `react-native-svg-transformer` (typed in
  `src/types/svg.d.ts`).

### Copy And Accessibility

- Every user-facing string lives in `i18n/` and is read with `useTranslation`.
  That includes alerts and accessibility copy.
- Interactive elements need `accessibilityLabel` and `accessibilityRole`, plus
  `accessibilityHint` / `accessibilityState` where they add meaning.
- Namespace new keys under the feature they belong to; add them to every locale
  file, not just the default.

### Adapters

Feature code should not import native SDKs or external capability packages
directly. Use app-facing adapters:

- `utils/storage` for persisted storage.
- `utils/toast` for imperative toast messages (never the visual layer under
  `theme/ui`, which loses queueing and defaults).
- `utils/logger` for logging.
- `utils/error-handling` for error capture and messages.
- `utils/haptic-feedback` for native haptics.
- `utils/services` for env and platform lookups.

A new native capability gets a `utils/<capability>/` adapter with the same
shape before any feature imports it.

## Code Style

- Use function declarations for React components.
- Prefer named exports.
- Keep TypeScript strict; avoid `any`. Use `unknown` when a value is truly
  unknown, `Record<string, unknown>` for loose object shapes.
- Use `type` for object shapes and unions.
- Prefer `as const` objects over enums.
- Prefer `undefined` for optional values.
- Use explicit parameter and return types for exported functions, thunks,
  utilities, and non-trivial callbacks.
- Let ESLint sort imports and exports; do not hand-order them.
- Keep Redux Toolkit Immer mutations named `state` or `draft` — the
  `no-param-reassign` exemption is scoped to those names.
- `console.warn` is the only permitted console call; everything else goes
  through `utils/logger`.
- JSX prop order that lint enforces: `key`, then shorthand booleans, then
  regular props alphabetically, then callbacks last.

Prettier settings:

- Single quotes.
- Trailing commas everywhere possible.
- `arrowParens: avoid`.
- `bracketSameLine: true`.
- `bracketSpacing: true`.

Let lint and Prettier shape import order and style order.

## Testing

`yarn test:unit` runs `jest.unit.config.js` — a **pure-logic** suite:
`testEnvironment: node`, no renderer, `react-native` mocked down to
`Dimensions`, `NativeModules`, and `Platform` in `jest.unit.setup.ts` (which
also mocks bootsplash and device-info, and sets `__DEV__ = false`).

- `testMatch` is `['**/*.test.ts']`. A `.test.tsx` file is **silently skipped** —
  it looks green and never runs. Component tests are not supported here.
- Tests sit next to their source as `<source>.test.ts`.
- Importing a screen or component into a unit test throws at collection time;
  the mocked `react-native` has no components. Test the extracted pure function
  instead.
- Anything native beyond what the setup file mocks (MMKV, notifications,
  purchases) must be mocked per file — or, better, kept out of the unit under
  test.
- Test non-trivial logic: merge rules, persist transforms, teardown, ordering,
  eligibility, edge-case utils. Skip trivial getter/re-export tests. No
  snapshots.
- Name `it` blocks after observable behavior, using `CONTEXT.md` vocabulary.

## Validation

Run the checks that match the change, then say which ran and which did not.

| Change scope | Run | Skip |
| --- | --- | --- |
| Pure `.ts` logic | focused `test:unit`, then `tsc` | madge |
| UI / `.tsx` | `tsc`, `lint` | unit tests (the config won't match them) |
| Imports, barrels, module boundaries | the above plus `madge` | |
| Broad refactor | `sanity` — reading the full output | |
| Docs or comments | `lint` on the touched scope | everything else |

**Baseline before blaming yourself.** If a check fails, re-run it against a
clean tree (`git stash && <check> ; git stash pop`). A failure that reproduces
without your change is pre-existing: report it as such and leave it alone —
fixing baseline issues inside a feature diff bloats review. A failure that
appears only with your change is yours.

End meaningful work with a checks section where every line is a result or an
explicit skip reason:

```text
Checks:
- yarn test:unit src/common/types/asyncStatus.test.ts — pass (6 tests)
- yarn tsc — pass
- yarn lint — pass
- yarn madge — skipped (no import or barrel changes)
- native run — skipped (no runtime-only behavior changed)
```

A check you did not run and did not mention reads as a check that passed.

## Docs

- `CONTEXT.md` for project vocabulary and boundaries — use its terms exactly.
- ADRs under `docs/adr/` for decisions that change module ownership,
  persistence, native behavior, or long-lived product semantics. A change that
  contradicts an existing ADR needs a new ADR, not a quiet override.
- `troubleshooting.md` for setup/build issues likely to recur.
- Update this file when a convention here stops being true.

## Never Do

- Never import `modules/<name>/<internal-file>` from another module.
- Never import `StyleSheet` from `react-native`.
- Never put a color literal, inline style, or hardcoded user-facing string in
  feature code.
- Never hardcode a slice, persist, or route key — derive it from `MODULE_NAME`.
- Never add a slice holding device-local paths or large blobs to the persisted
  root without a transform.
- Never name a unit test `.test.tsx`; it will not run.
- Never weaken an existing persist, merge, or teardown assertion to make a
  change pass — those tests are the data-integrity contract.
- Never introduce RTK Query, AsyncStorage, TypeScript `enum`, `@/` aliases,
  snapshot tests, or `runOnJS`.
- Never claim a check passed without running it.
