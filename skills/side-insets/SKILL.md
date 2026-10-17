---
name: side-insets
description: >
  Make a React Native layout correct when the window has a left or right
  safe-area inset: the status bar in a column on the side of a foldable such
  as iPhone Duo, a landscape phone, or a resized window. Covers full-bleed
  rows and backgrounds, a paging carousel sized from its own width, a hero
  height cap for short windows, floating chrome, and readable widths on wide
  windows. Use when the user says "rails stop at a hard line", "the carousel
  drifts", "cards are cut off", "the backdrop does not reach the edge",
  "content is under the status bar column", "make it work on the foldable",
  "iPhone Duo layout", or "fix landscape"; or before touching the shared
  Screen wrapper, a SafeAreaView with left or right edges, a horizontal
  ScrollView or FlatList, or a carousel with pagingEnabled.
---

# Side insets

A side inset keeps **content** clear of a status bar column or a notch. It
never clips a **background**, a row or a carousel. Most layout bugs on a
foldable or a landscape phone come from code that breaks this rule.

A regular phone held upright has side insets of 0. That is why these bugs hide
until a device with a side inset runs the app. It is also how you keep the
fix safe: every new value must reduce to the old value when the inset is 0.

## Phase 1 — find the root cause

Read the screen wrapper first. Find the component that every screen renders,
and check what it does with `edges`:

```sh
grep -rn "SafeAreaView\|useSafeAreaInsets\|edges=" src/ | grep -v test
```

The usual root cause: the wrapper pads its whole body by the left and right
insets. A `UIScrollView` clips to its own frame. So every vertical scroll view
in the app is narrowed, and everything inside it stops at the inset.

Each symptom below comes from that one cause:

| Symptom | Mechanism |
| --- | --- |
| A horizontal row ends at a hard vertical line | The row is inside the narrowed vertical scroll view. |
| A paging carousel lands further off on each page | `pagingEnabled` pages by the **frame** width, but each page is the **window** width. The error adds up. |
| A backdrop leaves a strip of page colour at the side | The backdrop is inside the padded body. |
| A floating tab bar sits under the status bar column | Chrome that floats over the window does not read the side insets. |

Also grep for layout that reads the window size once at module load, and for
device checks:

```sh
grep -rn "Dimensions.get\|Platform.isPad\|isTablet\|getDeviceType" src/
```

A module-level `Dimensions.get` cannot follow a size change. A device check is
the wrong question: the layout depends on the window, not the device. Do not
add either one.

## Phase 2 — the pattern

### 1. Let the wrapper say what it pads

Keep the wrapper's default. Publish the side insets it applies through a React
context. Three hooks read that context:

```ts
// The side insets that the enclosing screen wrapper already pads.
export const AppliedSideInsetsContext = createContext<HorizontalInsets>(NONE);

// The side insets this subtree must still pad. Zero inside a padded wrapper.
export function useHorizontalInsets(): HorizontalInsets {
  const insets = useSafeAreaInsets();
  const applied = useContext(AppliedSideInsetsContext);
  const left = Math.max(0, insets.left - applied.left);
  const right = Math.max(0, insets.right - applied.right);
  return useMemo(() => ({ left, right }), [left, right]);
}

// How far a background layer must reach out to touch the physical edge.
export function useHorizontalBleed(): HorizontalInsets {
  return useContext(AppliedSideInsetsContext);
}

// A horizontal row that spans the physical width, first item on the gutter.
// `nested` is the padding of a padded block the row sits in.
export function useRailInsets(nested = 0): RailInsets {
  const { left, right } = useHorizontalInsets();
  const gutter = theme.gutter.md; // read the repo's own gutter token
  return useMemo(
    () => ({
      contentContainerStyle: { paddingLeft: left + gutter, paddingRight: right + gutter },
      style: { marginLeft: -(left + nested), marginRight: -(right + nested) },
    }),
    [gutter, left, nested, right],
  );
}
```

The wrapper computes `applied` from its own `edges` and wraps its body in the
provider. Outside every screen, `applied` is zero, so floating chrome gets the
full inset from `useHorizontalInsets`.

### 2. Make the screens with rows full-bleed

A screen that hosts a horizontal row, a carousel or an edge-to-edge backdrop:

- Passes **no** side edges to the wrapper (`edges={[]}`, or top and bottom only).
- Pads its scroll `contentContainerStyle` by `useHorizontalInsets`.
- Pads any absolute header by the side inset plus the gutter.

A screen with no row can stay padded. Inside it, a full-bleed layer, such as a
top-bar scrim or a menu dim, uses `left: -bleed.left, right: -bleed.right`.
Its buttons and panels pad by `useHorizontalInsets` so they stay clear.

### 3. Run every row edge to edge

Every horizontal `ScrollView` and `FlatList` takes `useRailInsets`: `style` on
the list, `contentContainerStyle` on its content. Find them all:

```sh
grep -rln "horizontal" src/ | xargs grep -ln "ScrollView\|FlatList"
```

A row that used `marginHorizontal: -gutter` to escape a padded section passes
that gutter as `nested`. A row with an edge fade applies the hook to the
wrapper view, so the fade moves out with the row.

### 4. Size a paging carousel from its own width

Never size the pages from `useWindowDimensions`. Measure the list:

- Store the width from `onLayout`. Use `itemWidth ?? measuredWidth ?? windowWidth`.
- Keep the settled index in a shared value or a ref.
- When the width changes, call
  `scrollToOffset({ animated: false, offset: index * pageWidth })`. Without it,
  a fold or a rotation leaves the carousel between two pages.
- Pass the measured width to `getItemLayout` and `snapToInterval`, if the list
  uses them.

A carousel that looked like it had a "peek" of the next card may only have had
the drift error. Check that before you add a peek back.

### 5. Cap the hero height on short windows

A portrait hero sized from the width alone can fill a short window, such as a
foldable's outer display, and push the next section under the tab bar. Cap the
height with a token: a share of the window height, in a `max` with the old
aspect ratio. Choose a share that does not bind on the shortest regular phone
you support, or record the change it makes there.

### 6. Pad floating chrome

A floating tab bar, a search button, a toast or a dock pads by
`insets.left + gutter` and `insets.right + gutter`. Any width it computes
subtracts both insets.

### 7. Cap readable widths on wide windows

Give running text a `maxWidth` token (about 80 characters of body copy) and
the primary action block a `maxWidth` token. Make both wider than every phone,
so a phone does not change.

## Rules

- Use theme tokens for every new value. Name each new token in the handoff.
- Base layout on the window and the insets. Never on device type, orientation
  or a named screen size.
- Layout must follow a size change during a session. Every value comes from a
  hook, never from module scope.
- Do not change visual design or copy. This work moves boundaries only.

## Verify

Static checks cannot see a side inset. Run the app on a simulator that has
one, and on a regular phone.

- **Before and after.** Take a screenshot before the first edit, on both
  devices. A clean worktree makes this easy: build `main`, screenshot, then
  apply the change.
- **Pixel-diff the regular phone.** It must not change. `references/pxdiff.swift`
  compares two PNGs with AppKit and needs no Python packages:

  ```sh
  swift references/pxdiff.swift before.png after.png
  ```

- **Size changes.** Fold and unfold, or rotate, during use and mid-scroll.
  Check that the carousel keeps its page.

Traps found on Xcode 27.1:

- `simctl` has no fold control. A foldable simulator needs the Simulator app's
  menu, so the user must fold it by hand.
- `idb ui tap` fails, because `SimulatorKit.framework` is no longer at the path
  `idb_companion` loads. A deep link that opens an "Open in …?" prompt then
  blocks the run, because nothing can tap it.
- An app binary from before a React Native upgrade fails on the new bundle with
  an error such as "undefined is not a function" in worklets. Rebuild it.

Traps in a git worktree:

- A symlinked `node_modules` breaks Metro resolution (for example
  `@babel/runtime`). Clone it instead: `cp -Rc <main>/node_modules .`, and add
  `node_modules` to `.git/info/exclude`.
- Copy the git-ignored `.env`. Without it, build-time config is empty.
- `pod install` in a worktree rewrites paths in `Podfile.lock` and
  `project.pbxproj`. Revert both before you commit.

## Definition of done

- [ ] Every horizontal row, carousel and edge-to-edge background reaches the
      physical edge on a window with a side inset.
- [ ] All text, buttons and floating chrome stay clear of the inset.
- [ ] The carousel pages exactly, and keeps its page across a size change.
- [ ] The regular phone is pixel-identical, or each difference is named.
- [ ] No device checks and no module-level window reads were added.
- [ ] Every new token is named in the handoff.
- [ ] What could not be verified on a device is stated in the handoff.
- [ ] The rule is recorded where the repo keeps decisions (an ADR or the agent
      instructions), so the next screen follows it.
