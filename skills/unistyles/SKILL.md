---
name: unistyles
description: Style React Native components with react-native-unistyles (StyleSheet.create, theme tokens, variants, breakpoints, runtime). Use whenever writing or editing styles in this codebase, or when asked about Unistyles APIs, theming, or migration behavior.
---

## Ground yourself in this repo first

Before writing a single style, read the project's actual theme setup — token
names differ between projects and inventing one is the most common failure here.

- Find the theme config (conventionally `src/theme/`): the tokens file, the
  `AppTheme`/`AppThemes` types, the module augmentation + `configureAppThemes()`
  call, and the color palettes. Read the token names off it; never guess them.
- Find the shared UI primitives (conventionally `src/theme/ui/`). Feature screens
  import primitives from that barrel, not from internal files.
- Open one existing styled component and copy its shape — that is the house
  pattern, whatever this skill says.

## House rules

- Always `import { StyleSheet } from 'react-native-unistyles';` — never from `react-native`.
- Write styles as `const styles = StyleSheet.create(theme => ({ ... }))` and pull tokens off
  `theme` (colors, typography, spacing, radii, shadows, z-index). No color literals in feature UI.
- Static layout belongs in `StyleSheet.create`; only reach for prop-derived inline styles when a
  value truly depends on runtime data (e.g. a measured height). Never use single-element style arrays.
- Colocate a `styles.ts` next to the component when the stylesheet gets long enough to bury the JSX.

## Local reference (use this before fetching anything)

`references/unistyles.md` is the full Unistyles 3.0 docs (llms-full.txt), already saved locally —
grep it instead of using WebFetch. Section index:

| Topic                                           | Grep for                                           |
| ----------------------------------------------- | -------------------------------------------------- |
| Config (themes/breakpoints/settings)            | `^# Configuration`                                 |
| Getting started                                 | `^# Getting started`                               |
| How Unistyles works (compiler, no re-renders)   | `^# How Unistyles works`                           |
| Migration from v2                               | `^# Migration guide`                               |
| Testing                                         | `^# Testing`                                       |
| Theming (create/switch themes, scoped theme)    | `^# Theming`, `^# Scoped Theme`                    |
| Breakpoints / Media queries                     | `^# Breakpoints`, `^# Media Queries`               |
| Variants / Compound Variants                    | `^# Variants`, `^# Compound Variants`              |
| `StyleSheet` API                                | `^# StyleSheet`                                    |
| `useUnistyles` hook                             | `^# useUnistyles`                                  |
| Unistyles Runtime (`UnistylesRuntime`, setters) | `^# Unistyles Runtime`, `^## Setters`              |
| Dynamic functions                               | `^# Dynamic Functions`                             |
| Merging styles                                  | `^# Merging styles`                                |
| Reanimated integration                          | `^# Reanimated`                                    |
| Web-only features / SSR / Expo Router           | `^# Web only features`, `^# SSR`, `^# Expo Router` |
| `withUnistyles` (wrapping 3rd-party components) | `^# withUnistyles`                                 |
| FAQ / troubleshooting                           | `^# FAQ`, `^## Troubleshooting`                    |

Example: `grep -n -A 40 '^# Variants' references/unistyles.md`

Only fetch the remote docs (below) if the local copy seems stale for a question about a very
recent release.

## Documentation Sets (fallback, remote)

- [Abridged documentation](https://unistyl.es/llms-small.txt)
- [Complete documentation](https://unistyl.es/llms-full.txt)
