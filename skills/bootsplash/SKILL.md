---
name: bootsplash
description: >
  Set up and debug the launch screen / splash in a React Native app using
  react-native-bootsplash, including light and dark variants without the paid
  license key. Use when the user asks about the splash screen, launch screen,
  bootsplash, app startup flash, a logo that is wrong or stale on launch, or a
  splash that stays light in dark mode; when regenerating splash assets; or
  before touching BootSplash.storyboard, values-night/, drawable-night-*/, or
  the bootsplash asset catalogs.
---

# Launch screen / bootsplash

The splash is rendered by **three** different things in sequence, each with its
own light/dark mechanism. All three have to agree or the handoff flashes:

| # | Surface | Light/dark comes from |
| --- | --- | --- |
| 1 | iOS launch screen (`BootSplash.storyboard`) | asset catalog appearance variants |
| 2 | Android launch theme (`Theme.BootSplash`) | `values-night/` + `drawable-night-*/` |
| 3 | JS overlay (`AnimatedBootSplash.tsx`) | `manifest.darkBackground` + `darkLogo` |

**1 and 2 render before any JS runs**, so they cannot read Unistyles or
`useColorScheme` — the split has to be baked into native resources.

## Sources of truth

| | Light | Dark |
| --- | --- | --- |
| Logo | `bootsplash/logo-light.svg` | `bootsplash/logo-dark.svg` |
| Background | the theme's light `surface` token | the theme's dark `surface` token |

The light side is passed to the CLI in the generate script (`--background` and
the SVG path). The dark side lives in the constants at the top of the dark
script.

Both backgrounds must mirror the app's theme file so the splash hands off to the
first screen with no flash. **If you change `surface` in either theme, change it
in both places here too** — nothing enforces this automatically.

## Why a script instead of the CLI's own flags

`react-native-bootsplash` v7 ships `--dark-background`, `--dark-logo` and
`--dark-brand`, which would do all of this. They are gated behind a paid license
key (`--license-key`), and the generator prints an ad for it on every run.

Only **generation** is gated. The **runtime** dark support is free and fully
present — `useHideAnimation` already reads `manifest.darkBackground` and a
`darkLogo` prop (see
`node_modules/react-native-bootsplash/dist/commonjs/index.js`). So the script
only has to produce the assets the paid generator would have produced.

`references/bootsplash-dark.mjs` is that script. Wire it as the **second half**
of the generate script, because the generator overwrites the iOS asset catalogs,
the Android drawables and the JS manifest on every run — dropping everything the
dark pass added:

```json
"get-bootsplash": "yarn react-native-bootsplash generate bootsplash/logo-light.svg --platforms=android,ios --background=FBF9F4 --logo-width=180 --assets-output=src/assets/bootsplash --plist=ios/<App>/Info.plist && yarn bootsplash-dark",
"bootsplash-dark": "node scripts/bootsplash-dark.mjs"
```

So there is no manual step — `yarn get-bootsplash` regenerates the light assets
**and** re-applies every dark variant. Keep the dark script idempotent so it is
safe to re-run without regenerating.

If the project ever buys a key: delete the script, add the flags to the generate
script, and keep the `darkLogo` prop in `AnimatedBootSplash.tsx`.

## What the dark script does

Rasterises `logo-dark.svg` with **sharp** — the same engine the CLI uses, so the
light and dark PNGs render identically — then:

**iOS.** The storyboard never hardcodes a color or a file. It references two
*named* assets and UIKit resolves them against the trait collection at render
time, so **the storyboard itself is never edited**:

| Storyboard reference | Asset catalog |
| --- | --- |
| `backgroundColor` → `BootSplashBackground-<hash>` | `Colors.xcassets/BootSplashBackground-<hash>.colorset/` |
| `imageView.image` → `BootSplashLogo-<hash>` | `Images.xcassets/BootSplashLogo-<hash>.imageset/` |

The script writes `logo-<hash>-dark{,@2x,@3x}.png` and appends entries carrying
`"appearances": [{ "appearance": "luminosity", "value": "dark" }]` to both
`Contents.json` files. Entries *without* an `appearances` key are the light /
"any appearance" fallback.

> The `<hash>` suffix is derived from the CLI's arguments and changes whenever
> they do. **Discover it by globbing rather than hardcoding it** — do the same in
> any new tooling.

**Android.** Writes `drawable-night-{mdpi…xxxhdpi}/bootsplash_logo.png` and
`values-night/colors.xml` overriding `bootsplash_background`. The resource
qualifier system picks these up; `styles.xml` needs no change.

**JS.** Writes `src/assets/bootsplash/logo-dark{,@1,5x,@2x,@3x,@4x}.png` and adds
`darkBackground` to `manifest.json`. `AnimatedBootSplash.tsx` passes
`darkLogo: require('assets/bootsplash/logo-dark.png')` — that require is the one
bit that is **not** generated, so don't remove it.

## Verifying iOS

A malformed `Contents.json` is **silently ignored** by `actool` — you would ship
light-only with no warning. Compile the catalogs and list what actually landed:

```sh
OUT=$(mktemp -d)
xcrun actool ios/<App>/Images.xcassets ios/<App>/Colors.xcassets \
  --compile "$OUT" --platform iphoneos --minimum-deployment-target 15.1 \
  --app-icon AppIcon --output-partial-info-plist "$OUT/p.plist" >/dev/null
xcrun assetutil --info "$OUT/Assets.car" | grep -i "name\|appearance" | grep -A1 BootSplash
```

Every `BootSplash*` asset should appear **twice** — once with no `Appearance`,
once as `UIAppearanceDark`.

## Testing on device/simulator

**iOS caches the launch image aggressively.** Toggling appearance and relaunching
usually shows the stale variant. To actually see the change:

1. Delete the app from the simulator/device, then rebuild — or
2. Erase All Content and Settings on the simulator.

Don't conclude it's broken from the first toggle.

`Info.plist` must have **no** `UIUserInterfaceStyle` key — that absence is what
lets the app follow the system appearance. If someone adds one to force a style,
the dark launch screen silently stops resolving.

## Gotcha: `mipmap/` vs `drawable/`

Older versions of the generator wrote `bootsplash_logo.png` into `mipmap-*/`; the
current one uses `drawable-*/`, which is what `styles.xml` references. A stale set
of mipmap copies can survive a generator upgrade and ship the old mark in the APK.

They are separate resource namespaces, so the stale files never shadow anything
and nothing breaks — which is exactly why it goes unnoticed. If the splash logo
looks right in `drawable-*/` but wrong in a build, check for leftovers in
`mipmap-*/`.

## Danger zone — never do

- Never hand-edit `BootSplash.storyboard` to add a dark color — it references
  named assets precisely so it doesn't need editing.
- Never hardcode the generator's `<hash>` suffix — glob for it.
- Never run the dark script *before* the generator; the generator overwrites its
  output.
- Never add `UIUserInterfaceStyle` to `Info.plist` unless you intend to kill dark
  mode everywhere, splash included.
- Never change a theme's `surface` token without updating the generate script's
  `--background` and the dark script's constant.
- Never trust one appearance toggle on the simulator — delete and rebuild.

## Definition of done

- [ ] `yarn get-bootsplash` runs clean and re-applies dark in one command.
- [ ] `assetutil` shows every `BootSplash*` asset twice (default + `UIAppearanceDark`).
- [ ] Both appearances checked after a delete-and-reinstall, on iOS and Android.
- [ ] No flash at handoff — splash background matches the first screen in both themes.
- [ ] No stale `mipmap-*/bootsplash_logo.png` left behind.
