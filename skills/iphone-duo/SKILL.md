---
name: iphone-duo
description: >
  Make a React Native iOS app give the best experience on iPhone Duo, the
  foldable with an outer and an inner display. Covers the audit for screen
  reads, orientation logic, device and idiom checks, hardcoded sizes and native
  UIScreen.main use; width classes instead of device checks; an iPad-like
  layout on the inner display; vertical system bars from the iOS 27.1 SDK; tab
  bar to sidebar; full-bleed media; sheets; Split View; the pose test matrix in
  Device Hub; and the App Store screenshot rule. Use when the user says
  "prepare for iPhone Duo", "optimize for the foldable", "the app looks like a
  big phone when unfolded", "support all poses", "Split View on Duo", "Duo
  screenshots", or "build with the iOS 27.1 SDK"; or before adding a tablet
  layout, a breakpoint, an orientation lock or a device check.
---

# iPhone Duo

iPhone Duo has two displays. The outer display acts like a regular iPhone. The
inner display has **regular** horizontal and vertical size classes, like an
iPad. An app built with the iOS 27 SDK or later resizes when the user folds or
unfolds the device, during the session.

This skill owns the adaptive layout. The `side-insets` skill owns the
mechanics of a left or right safe-area inset (full-bleed rows, the paging
carousel, floating chrome). Load both. Do the `side-insets` work first,
because every pose on Duo can have a side inset.

Source: developer.apple.com/iphone-duo/prepare and the Tech Talk "Prepare your
app for iPhone Duo". Read them again if a rule here looks out of date.

## What the SDK changes

| Built with | Outer display | Inner display |
| --- | --- | --- |
| iOS 26 SDK or earlier | Content to the left of the status bar and camera. | Centered, empty space around it. |
| iOS 27 SDK | Resizes. | Fills most of the display, avoids the status bar on the right edge. |
| iOS 27.1 SDK or later | Full display. | Full display. Toolbars and tab bars become **vertical**, below the status bar. |

Apple's one hard rule: before you ship a build with the iOS 27.1 SDK, make
sure that content adapts to the vertical bars. A vertical bar gives a leading
or trailing inset, not a top or bottom inset.

Find the Xcode version that the app builds with, on the machine and on CI:

```sh
xcodebuild -version
grep -rn "xcode" .github/ ci_scripts/ ios/ci_scripts/ 2>/dev/null | grep -i version
```

On Xcode Cloud, the Xcode version is a workflow setting. See the `xcode-cloud`
skill.

## Phase 1 — audit

Run every search. Record each hit before you change code.

### JavaScript

```sh
# Screen size, not window size. Wrong on a device with two displays.
grep -rn "Dimensions.get('screen')\|Dimensions.get(\"screen\")" src/
# Window size read once. Cannot follow a fold.
grep -rn "Dimensions.get" src/ | grep -v "use[A-Z]"
# Orientation logic and orientation locks.
grep -rn "orientation\|Orientation\|isLandscape\|isPortrait" src/ package.json
# Device and idiom checks.
grep -rn "Platform.isPad\|isTablet\|getDeviceType\|getModel\|hasNotch\|isIphoneX\|getStatusBarHeight" src/ package.json
# Hardcoded device sizes.
grep -rnE "(width|height) *[=!<>]=* *(320|375|390|393|402|414|428|430|440|667|736|812|844|852|874|896|926|932|956)\b" src/
# Pixel ratio read at module scope.
grep -rn "PixelRatio.get" src/
# Media that fills and crops.
grep -rn "resizeMode=\"cover\"\|contentFit=\"cover\"\|resizeMode: 'cover'\|contentFit: 'cover'" src/
```

### Native

```sh
grep -rn "UIScreen.main\|UIScreen.mainScreen\|\[UIScreen mainScreen\]" ios/ --include='*.swift' --include='*.m' --include='*.mm' --include='*.h' | grep -v "ios/Pods/"
grep -rn "UIWindow(frame:\|initWithFrame:\[\[UIScreen" ios/ --include='*.swift' --include='*.m' --include='*.mm' | grep -v "ios/Pods/"
grep -rln "UIScreen.main\|mainScreen\]" ios/Pods/ 2>/dev/null | cut -d/ -f3 | sort -u
plutil -p ios/*/Info.plist | grep -A6 "UISupportedInterfaceOrientations\|UIRequiresFullScreen"
```

The last `ios/Pods/` search lists third-party pods that read the main screen.
Do not edit a pod. Name each one in the handoff, and check whether a newer
version of the library fixes it.

## Phase 2 — fixes

### 1. Read the window, never the screen

- In JavaScript, use `useWindowDimensions` in render, or `onLayout` for the
  size of one view. Replace `Dimensions.get('screen')` and every module-level
  `Dimensions.get`.
- Read `PixelRatio.get()` in render or in a hook, not at module scope. The
  scale can change when the app moves to the other display.
- In native code, replace `UIScreen.main.bounds` with `view.bounds` or
  `window.bounds`. Replace `UIScreen.main.scale` with
  `traitCollection.displayScale`. Replace `UIWindow(frame: UIScreen.main.bounds)`
  with `UIWindow(windowScene:)`. Get the screen when you need it:
  `view.window?.windowScene?.screen`. Do not store a `UIScreen`.
- A pre-0.88 React Native template creates the window with
  `UIWindow(frame: UIScreen.main.bounds)` in `AppDelegate`. The fix is the
  `SceneDelegate` start. See the `upgrade-react-native` skill.

### 2. Remove orientation logic

The inner display does not honor the supported interface orientations. The
app also scales there in Split View. So orientation does not tell you the
shape of the window.

- Replace each `isLandscape` decision with `width > height` from
  `useWindowDimensions`, or from `onLayout` of the view that the decision is
  for.
- Remove an orientation lock that only protects a phone layout. Keep a lock
  only when the content needs it (for example a camera screen), and test that
  screen on the inner display.
- `UIRequiresFullScreen` still applies on Duo, but the app still resizes on a
  fold. It is not a way to avoid this work.

### 3. Replace device checks with width classes

Size class is not device type. On Duo and in resizable iPhone Mirroring, an
iPhone app can have any combination of size classes. A layout that keys
`Platform.isPad` or `isTablet` never shows on the Duo inner display. A layout
that keys "wide" to iPad now runs on an iPhone.

- Define width classes as theme tokens, from the window width. If the repo
  uses Unistyles, use its `breakpoints` and `mq`. See the `unistyles` skill.
- Use two classes at minimum: **compact** (every regular phone, the outer
  display, a narrow Split View) and **regular** (the inner display, iPad).
  Set the boundary token wider than the widest phone in portrait. Check it
  against each Duo pose and each Split View width in the simulator.
- Replace every device check and every hardcoded size with a width class.
  Do not add a `isDuo` check. It fails on the next device.
- A height class is useful for a short window. The `side-insets` hero cap
  is one example.

### 4. Give the inner display an iPad-like layout

Apple asks that the inner display looks like a natural extension of the iPad
layout, not a large phone. On the **regular** width class:

- **List and detail.** Show the list and the selected detail side by side.
  Keep one navigation state, so a fold to compact shows the detail as a pushed
  screen, and an unfold shows both columns again. Do not lose the selection.
- **Grids.** Compute the column count from the measured width and a minimum
  cell width token. Never from device type.
- **Readable width.** Cap running text and forms with the `maxWidth` tokens
  from `side-insets`. Center the capped block, or use the free space for a
  second column.
- **Navigation bar.** On a regular width, a JavaScript tab bar becomes a
  vertical rail or a sidebar on the leading edge. Pad it by the leading side
  inset. A native tab bar (`UITabBarController`) adapts by itself. To get the
  sidebar, it needs `tabBarController.sidebar.preferredPlacement = .sidebar`.
  Check that the tab library in the repo exposes that, before you write a
  JavaScript rail.
- Keep the same screens, the same copy and the same order of actions on every
  pose. Only the arrangement changes.

### 5. Adapt to vertical bars and asymmetric insets

With the iOS 27.1 SDK, system toolbars and tab bars on Duo are vertical.
Vertical bars give leading and trailing insets. The left and right insets are
not equal.

- Read each side from `useSafeAreaInsets()` separately. Never use one value
  for both sides, and never compute `(width - content) / 2` with the insets
  removed from one side only.
- Foreground content stays inside the safe area. Backgrounds extend past it.
  This is the `side-insets` rule.
- A custom bar that sits at the edge must not cover system UI. iOS 27.1 adds
  `UIViewReservedRegion` for this. React Native has no API for it, and
  `react-native-safe-area-context` does not report it. Keep custom bars inside
  the safe area, and record this limit in the handoff.

### 6. Fit full-bleed media to the window shape

A hero image or a video with `cover` crops more on a wide window, and can cut
off a face or a product.

- Choose `cover` or `contain` from the aspect ratio of the window, or of the
  measured container.
- Or keep `cover` and set a focal point (for example `contentPosition` in
  `expo-image`), so the important part stays in view.
- Check each hero on the inner display, open, in both orientations.

### 7. Check sheets, modals and menus

System sheets, popovers, context menus and alerts adapt to each pose. On the
inner display a system sheet is centered. A JavaScript sheet does not do this.

- On the regular width class, give a custom sheet a `maxWidth` token and
  center it, or present it as a form sheet.
- For `@lodev09/react-native-true-sheet`, see the `truesheet-usage` skill.
- A sheet must keep its state across a fold. Test a fold with the sheet open.

### 8. Keep state across a fold

A fold changes the window size. It does not remount the app. Check that a
fold does not reset scroll position, form input, video playback, the open
sheet, the carousel page or the list selection. A `key` that contains the
width remounts a subtree. Remove it.

## Rules

- Base layout on the window size, the measured view size and the safe-area
  insets. Never on device model, idiom, orientation or a named screen size.
- Every size value comes from a hook or a layout event, never from module
  scope.
- Use theme tokens for every breakpoint and every new value. Name each new
  token in the handoff.
- A regular phone must not change. Prove it with the `side-insets` pixel diff.

## Verify

Use the iPhone Duo simulator in Xcode 27.1 or later. Open it from Device Hub.
Its on-screen buttons open, close, rotate and fold the device. There is no
command-line fold control, so ask the user to change the pose when you
cannot click.

Test this matrix. Take a screenshot of each cell:

| Pose | Check |
| --- | --- |
| Closed, portrait | Same as a regular phone. Content clear of the status bar column. |
| Closed, landscape | Side insets on both sides. Rows run edge to edge. |
| Open, portrait and landscape | Regular layout: columns, sidebar or rail, capped text. |
| Open, Split View on the left, then on the right | Drag the app by the home indicator. Compact layout in the narrow window. Vertical bars can be on either side. |
| Fold and unfold mid-use | State from section 8 stays. Carousel keeps its page. |

Also resize an iPhone Mirroring window on macOS 27 to extreme sizes, in both
directions. It shows layouts that the fixed poses do not.

Run the `side-insets` pixel diff on a regular phone. Use the `verify` skill
to build, launch and take screenshots.

## Ship

- Build the release with Xcode 27.1 or later, so the app gets the full-display
  layout.
- App Store Connect shows an iPhone Duo badge on the product page when the app
  has iPhone Duo screenshots. From April 2027, every app submission must
  include iPhone Duo screenshots. Take them from the pose matrix, and tell the
  user before the next submission.
- In a featuring nomination, the "Helpful Details" field can say "optimized
  for iPhone Duo, including support for all device poses". Say it only when
  every cell of the matrix passes.

## Definition of done

- [ ] No screen read, module-level window read, orientation decision, device
      check or hardcoded device size is left in `src/`.
- [ ] No `UIScreen.main` and no `UIWindow(frame:)` in the app's own native code.
      Each pod that still reads the main screen is named in the handoff.
- [ ] The `side-insets` definition of done passes.
- [ ] The inner display shows the regular layout. A fold and an unfold keep
      the state.
- [ ] Every cell of the pose matrix has a screenshot.
- [ ] The regular phone is pixel-identical, or each difference is named.
- [ ] The Xcode version for release builds, the screenshot rule and each item
      that was not verified on a device are stated in the handoff.
