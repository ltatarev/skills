---
name: build-ui
description: >
  Builds screens, components, modals, and sheets to the house React Native UI
  standard. Use when the user asks to build or add a screen, component, modal,
  sheet, button, or any JSX; when doing styling, theming, animation, or gesture
  work; or before writing any StyleSheet, translation key, or accessibility
  prop in a React Native project. Covers Unistyles v3 patterns, composing from
  the shared UI kit instead of raw RN primitives, the i18n + a11y procedure,
  and worklet rules.
---

# Building UI

The procedure for authoring any JSX in a React Native repo built to the house
standard: Unistyles v3 stylesheets with theme tokens only, shared `theme/ui`
components instead of raw React Native primitives, every user-facing string in
i18n with accessibility props, and worklet-safe gesture code.

## Procedure

1. **Ground yourself in this repo first.** Token names, primitive names, and
   i18n key namespaces differ between projects — inventing one is the most
   common failure. Before writing anything:
   - Read the theme tokens file (conventionally `src/theme/theme.ts`) and note
     the real token paths (`theme.colors.*`, `theme.spacing.*`, radii, shadows).
   - Read the shared UI barrel (conventionally `src/theme/ui/index.ts`) and list
     what already exists. Do not write a component the kit already has.
   - Open one existing screen and one existing shared primitive. That is the
     house pattern, whatever this skill says.
   - Read `AGENTS.md` / `CLAUDE.md` if present.
2. Decide where the component lives (see "Where a component belongs").
3. Write styles with `StyleSheet.create(theme => ({...}))` imported from
   `react-native-unistyles`, using only tokens that exist in the theme file.
4. Add every user-facing string (including a11y labels and hints) to the i18n
   catalog and read it via `useTranslation`.
5. Add `accessibilityLabel`, `accessibilityRole`, and where helpful
   `accessibilityHint` and `accessibilityState` to every interactive element.
6. Run lint and typecheck. See `validate-change` for which checks match the scope.

## Key files to locate (names vary by repo — verify, don't assume)

| What | Conventionally | How to confirm |
| --- | --- | --- |
| Theme tokens (the only place color literals live) | `src/theme/theme.ts` | grep for the hex literals |
| Unistyles registration / theme types | `src/theme/unistyles.ts`, `src/theme/types.ts` | grep `StyleSheet.configure` |
| Shared UI barrel | `src/theme/ui/index.ts` | the barrel other modules import |
| User-facing copy | `i18n/<locale>.json` | grep an existing `t('...')` key |
| Toast adapter | `src/utils/toast.tsx` | grep `showToast` |

## Unistyles v3

- `import { StyleSheet } from 'react-native-unistyles'` — **never** from
  `react-native`. Importing from `react-native` bypasses theming and silently
  breaks light/dark.
- `const styles = StyleSheet.create(theme => ({ ... }))` at the bottom of the
  file, or in a colocated `styles.ts` when it gets long enough to bury the JSX.
  Purely static stylesheets may use the object form.
- Theme tokens only. A hex or `rgb()` in a component is a lint error.
- Values genuinely derived from runtime data (a measured height, an avatar
  diameter from props) are the one acceptable inline exception.
- Never `style={[styles.x]}` with a single element — use `style={styles.x}`.
- Never hand-order style properties; let `lint --fix` sort them.
- Platform splits: `Platform.select` for simple cases, `.ios.tsx` /
  `.android.tsx` for complex ones.

For anything beyond this — variants, breakpoints, scoped themes, runtime,
`withUnistyles`, Reanimated integration, v2 migration — load the `unistyles`
skill, which carries the full offline docs.

## Compose from the shared UI kit

Always compose from the repo's `theme/ui` primitives rather than raw
`react-native` components. Typical shape of such a kit:

- A `Text` component with boolean shorthand props (`title`, `subtitle`,
  `caption`, `bold`, `center`) — raw text outside it is a lint error.
- A `View` with layout shorthands (`flex1`, `row`, `center`, `middle`) —
  prefer these over one-off flex styles.
- A `Touchable` / `Button` family — the pressable surface with themed styling.
- Modal and sheet surfaces. For new bottom sheets, load the `truesheet-usage`
  skill.
- Image and avatar wrappers.

Read the barrel before writing a new primitive. If what you need is genuinely
missing and is presentation-only with no module imports, add it to `theme/ui`
and export it from the barrel — do not fork a local copy inside a module.

Long lists use `FlatList`, never `ScrollView` + `.map()`.

## i18n + accessibility procedure

1. Add keys to the i18n catalog under the feature's namespace.
2. Read them with `useTranslation` and pass translations to a11y props too —
   accessibility copy is user-facing copy.

```tsx
const { t } = useTranslation();
const selectLabel = t('settings.themePicker.selectTheme');
const label = `${selectLabel} ${displayName}`;

return (
  <Touchable
    accessible
    button
    accessibilityHint={selectLabel}
    accessibilityLabel={label}
    accessibilityRole="button"
    accessibilityState={{ selected }}
    style={styles.container}
    onPress={handlePress}>
```

Note the JSX prop order lint enforces: `key` first, then shorthand booleans,
then regular props alphabetically, then callbacks last.

## Toast

Import the app-facing `showToast` adapter (conventionally `utils/toast`), never
the visual layer under `theme/ui`. The adapter carries defaults and typically
queues toasts fired before the provider mounts; importing the runtime layer
directly loses both.

## Worklets and gestures

Call JS from a worklet with `scheduleOnRN` from `react-native-worklets`:

```tsx
.onEnd(event => {
  'worklet';

  const shouldDismiss =
    event.translationY > dismissThreshold ||
    event.velocityY > dismissVelocityThreshold;

  if (shouldDismiss) {
    scheduleOnRN(onDismiss);
  }
})
```

Never import `runOnJS` from `react-native-reanimated` — it races under the
worklets runtime these apps use. Values read inside worklets must be
`useSharedValue`, not `useRef`. Mark worklet callbacks with the `'worklet'`
directive.

## Where a component belongs

- Reusable, presentation-only, no module or Redux imports → the shared
  `theme/ui` kit, exported from its barrel.
- Feature-specific → inside its module: `components/` for small pieces,
  `fragments/` for larger screen sections, `screens/` for route-level
  orchestration.
- Import other modules only via their barrel (`modules/<name>`). ESLint
  `no-restricted-imports` blocks internals and `madge` catches the cycles.

See `add-feature` for the full module anatomy. The layer rule: screens
orchestrate, fragments section, components present, hooks own logic. A component
that reaches for `useAppDispatch` or `useAppSelector` has taken on a job that
belongs to its screen's hook.

## Danger zone — never do

- Never `import { StyleSheet } from 'react-native'` — themes break silently.
- Never write a hex/rgb color in a component; colors live only in the theme file.
- Never use inline styles or single-element style arrays.
- Never put raw text outside the kit's `Text` component.
- Never hardcode user-facing strings, including alerts and a11y copy.
- Never import the toast visual layer from feature code — use the adapter.
- Never use `runOnJS`; use `scheduleOnRN`.
- Never call `setState` synchronously in a `useEffect` body — initialize
  `useState` with the right value instead.
- Never invent a theme token or i18n namespace you did not read from the repo.

## Definition of done

- [ ] Lint passes (run the `--fix` variant first for import/style order).
- [ ] Typecheck passes.
- [ ] New copy is in the i18n catalog; a11y labels/hints/roles present.
- [ ] Styles use real theme tokens; no color literals or inline styles.
- [ ] Imports go through module barrels; run `madge` if module imports changed.
- [ ] Long lists use `FlatList`.
- [ ] Optional: `verify` for runtime behavior, `gitmoji` if committing.
