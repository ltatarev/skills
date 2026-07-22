---
name: ios-widget
description: >
  Build and wire an iOS home-screen widget (WidgetKit) into a React Native app —
  the App Group snapshot architecture, adding the extension target to
  project.pbxproj by script, the Swift native module bridge, rendering the
  widget's image offscreen with Skia, dark mode, freshness, and the build
  verification traps. Use when the user asks to add, change, or debug a widget,
  a WidgetKit extension, an App Group, a home-screen widget, or a lock-screen
  widget; when a widget renders blank, stale, or light-only; or before touching
  anything under an ios/*Widget/ directory.
---

# iOS widgets in a React Native app

A widget extension is a **separate process with its own sandbox**. It cannot read
the app's container, cannot run JavaScript, and cannot host React Native.
Everything it draws has to be either (a) reimplemented in Swift, or (b) handed to
it through an App Group.

**Do (b).** Reimplementing means two implementations of the same visual kept in
sync by hand forever, plus forcing the database into the App Group. Record the
choice as an ADR — it is architectural, hard to reverse, and surprising without
context. Use `domain-modeling` for that.

## The shape of it

```
JS                                    native
──                                    ──────
<feature>/widget/render.tsx           ios/<App>/WidgetBridge.swift
  drawAsImage(<View/>) → PNG            writes App Group + reloadTimelines()
       ↓                                     ↓
hooks/useWidgetSync.ts                ios/Shared/WidgetStore.swift
  debounced publish on change           ← compiled into BOTH targets →
       ↓                                     ↓
utils/widget (adapter)      ──────►   ios/<App>Widget/<App>Widget.swift
  NativeModules.WidgetBridge            reads it, draws SwiftUI
```

| Piece | Owns |
| --- | --- |
| Offscreen render (`<feature>/widget/`) | one PNG per appearance, plus the counts/strings |
| Publish loop (`hooks/useWidgetSync.ts`) | when to republish |
| Adapter (`utils/widget/`) | the **only** place `NativeModules` is touched |
| Bridge (`ios/<App>/WidgetBridge.{swift,m}`) | writing the group, reloading timelines |
| Shared model (`ios/Shared/WidgetStore.swift`) | payload shape, atomic read/write |
| The widget (`ios/<App>Widget/`) | SwiftUI, timeline, families |

Extract the rendered subtree so **the widget and the on-screen view are the same
component**. If someone adds a visual to it, both get it for free. Do not fork it.

## Adding widgets to an app that has none

### 1. App Group

Two entitlements files, both listing the **identical** group id — the app's and
the extension's — and the same string in the shared Swift store. If any of the
three drift, `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil
and **every write throws**; the widget just silently stays empty.

The group also has to exist on the Apple Developer account behind the signing
team (`DEVELOPMENT_TEAM`). With automatic signing, opening the project in Xcode
once and letting it repair profiles usually creates it.

### 2. The extension target

Do **not** hand-edit `project.pbxproj`. CocoaPods already brings in the
`xcodeproj` gem, so script it — `references/add-widget-target.rb` is a working
starting point. Keep it **idempotent** (bail early if the target exists) so it
survives re-runs, `pod install`, and merges.

```sh
cd ios && bundle exec ruby scripts/add_widget_target.rb
```

What the script has to do:

- `project.new_target(:app_extension, name, :ios, '17.0', nil, :swift)`
- source files → widget target; bridge + shared store → **both** targets
- font resources → widget target (extensions do **not** inherit the app's fonts)
- build settings: `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, `SKIP_INSTALL=YES`,
  `GENERATE_INFOPLIST_FILE=NO`, bundle id = app's + `.widget`, plus
  `DEVELOPMENT_TEAM`, `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` copied
  off the app target
- `CODE_SIGN_ENTITLEMENTS` on the **app** target too
- a `PBXCopyFilesBuildPhase` named `Embed Foundation Extensions` with
  `symbol_dst_subfolder_spec = :plug_ins`, containing `widget.product_reference`,
  with `settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }`
- `app.add_dependency(widget)`

> **The trap that costs a build cycle.** Group *paths* are not group *names*. The
> RN template's app group has `path = nil`, so it resolves to `ios/` and its
> children spell out their own prefix (`<App>/Info.plist`). Calling
> `group.new_file('Foo.swift')` on it produces a ref to `ios/Foo.swift`, not
> `ios/<App>/Foo.swift`, and you find out at build time:
>
> ```
> error: Build input file cannot be found: '…/ios/WidgetBridge.swift'
> ```
>
> Assert `File.exist?(ref.real_path)` for every ref the script creates, so a path
> mistake aborts the script instead of surfacing minutes later in Xcode.

The extension's `Info.plist` needs `NSExtensionPointIdentifier` =
`com.apple.widgetkit-extension` and `CFBundlePackageType` = `XPC!`. Custom fonts
go in the extension's own `UIAppFonts`, and the `.otf` files must be in its
resources build phase — `Font.custom` **silently falls back to the system font**
if you forget, which is easy to miss.

### 3. The native module

WidgetKit is **Swift-only** — there is no Objective-C `WidgetCenter`. So the
bridge is a Swift class plus a thin `RCT_EXTERN_MODULE` shim:

```swift
@objc(WidgetBridge)
class WidgetBridge: NSObject {
  @objc static func requiresMainQueueSetup() -> Bool { false }
  @objc(publish:resolver:rejecter:)
  func publish(_ payload: NSDictionary, resolver resolve: @escaping RCTPromiseResolveBlock, …)
}
```

```objc
@interface RCT_EXTERN_MODULE (WidgetBridge, NSObject)
RCT_EXTERN_METHOD(publish : (NSDictionary *)payload resolver : …)
@end
```

`import React` in the Swift file gets you `RCTPromiseResolveBlock`; no bridging
header is needed, because the `RCT_EXTERN_MODULE` macro adds `RCTBridgeModule`
conformance from the ObjC side. Prefer promises over
`RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD` — sync methods are the shakiest part of
the bridgeless interop layer.

Do the file write **in Swift**, not in JS. The app group path is not derivable
from JS (`/private/var/mobile/Containers/Shared/AppGroup/<UUID>/`), so a single
`publish(payload)` call that writes the files and reloads is simpler and more
atomic than shipping a path back to JS and writing with `react-native-blob-util`.

### 4. Deployment target

`containerBackground(for:)` and `contentMarginsDisabled()` are **iOS 17+**. Set
the widget target's deployment target independently of the app's. Supporting
14–16 means availability-gating both and falling back to a plain background —
worth it only if the audience needs it.

## Adding another widget to an app that already has one

Once the infrastructure exists, most new widgets are three edits.

1. **Extend the payload** (if it needs new data). Add a field to the snapshot
   struct in the shared store. It is `Codable`, so **make new fields optional**
   (`let streak: Int?`) or a widget running against a payload written by an older
   app build fails to decode and goes blank. Mirror it in the JS adapter's type
   and in the bridge's `guard let` block — the bridge rejects the whole publish
   if a **required** field is missing, so add optional fields with
   `payload["x"] as? Int` and no `guard`. Anything that is a *color* almost
   certainly belongs on the per-appearance variant struct instead.
2. **Write the SwiftUI.** Add a `struct MyWidget: Widget`, then register it in
   the bundle — that is the whole registration:

   ```swift
   var body: some Widget {
     ExistingWidget()
     MyWidget()
   }
   ```

   New `.swift` files are **not** picked up automatically — add them to the
   target. Each `Widget` needs its own `kind` string; add a second constant
   rather than reusing the existing one, and reload the specific kind
   (`WidgetCenter.shared.reloadTimelines(ofKind:)`) rather than switching to
   `reloadAllTimelines()`.
3. **Publish when it should change.** If the data has a different trigger, add it
   to the existing sync effect rather than writing a second hook — two publishers
   racing on one payload file will clobber each other.

## Rendering offscreen with Skia — the constraints that bite

`drawAsImage(element, size)` from `@shopify/react-native-skia` renders a Skia
element tree (not a `<Canvas>`) into an `SkImage`. Two hard limits, both because
`SkiaSGRoot.render()` resolves on the **first commit**:

1. **Async Skia hooks never land.** `useImage` and `useFont` return null on first
   render and fill in via `useEffect`. That update arrives *after* the picture is
   already recorded. Anything they would provide is silently missing from the PNG.
2. **So preload, or skip.**
   - Images: decode ahead with `Skia.Data.fromURI` +
     `Skia.Image.MakeImageFromEncoded`, and pass the `SkImage` down as a prop the
     component prefers over its own `useImage`.
   - Fonts: prefer designing the text out of the widget render. Small type is
     unreadable at widget size anyway — let the constraint and the design agree.

Other notes:

- **Round the size.** `Skia.Surface.MakeOffscreen` allocates from it and
  fractional values are asking for trouble.
- **Render at pixel dimensions, not points.** Target roughly 3× the widest family
  you support so it resamples cleanly on a 3× screen.
- **Transparent ground.** The widget paints the background; the PNG should carry
  only the art.
- **Failures are logged, never toasted.** A stale widget is not worth
  interrupting anyone.

## Layouts

Lay each family out **separately** (`smallContent` / `mediumContent`), not one
view with size-dependent numbers.

To give an image the remaining space beside a text column, put
`.fixedSize(horizontal: true)` on the **text** so it takes only the width it
needs. Do **not** reach for `.layoutPriority(1)` on the image: a resizable `.fit`
image is flexible in *both* axes, so a high layout priority makes it accept the
full width proposal and the text column collapses to zero. **Priority belongs on
the inflexible side.**

## The empty state

Shown whenever there is no payload: a fresh install the app has not been opened
on, the widget gallery preview, wiped data, or a broken App Group. It cannot use
real user content, so generate a placeholder at build time **from the same core
the app draws with** — driving the real generation functions directly means the
placeholder cannot drift from the real thing. Keep it deterministic (fixed seed)
so an unchanged core produces an unchanged PNG.

Two details worth keeping:

- Make the placeholder PNG **alpha only** (white strokes on transparent) and draw
  it with `.renderingMode(.template)`, tinted from a token. One file then serves
  both appearances — no light/dark pair needed.
- Any string the widget derives rather than receives (e.g. a month name via
  `DateFormatter`) should be pinned to `en_US_POSIX` to match the app's own
  formatting.

## Dark mode

Two things decide what the widget draws.

**Which appearance.** Publish the app's three-way preference in the payload and
resolve it in Swift, so an explicit pin carries over to the home screen and
`system` defers to it:

```swift
switch entry.snapshot?.appearance {
case "light": return false          // pinned — ignore the home screen
case "dark":  return true
default:      return systemScheme == .dark   // "system", or no payload yet
}
```

The preference can change without any data mutation, so the sync hook must
republish off a preference subscription too.

**Which image.** Any chrome token baked into the PNG (outlines, hairlines,
sockets) forces **two renders** — publish `image-light.png` and `image-dark.png`.
Decode shared photos once and reuse them across both; the renders are sequential
because Skia's offscreen renderer drives one shared React reconciler. Colors that
are *content* rather than chrome do not change between appearances and need no
second render.

Chrome colors the widget applies itself (background, ink, muted) should ride in
the payload per variant, so they never need a re-render.

> Do **not** invent a background color for the widget. Use the same token the
> app's own screen uses. Matching the app is what makes dark mode fall out
> correctly.

The empty state has no payload to read colors from, so it falls back to hardcoded
tokens in Swift. Keep those in step with the theme file by hand.

## Freshness

The app can only publish while it is running. Everything else is the timeline:

```swift
policy: .after(nextDayAt0001)
```

iOS also budgets reloads — a widget that stops refreshing during testing usually
just needs removing from the home screen and re-adding.

## Localization

The widget cannot reach the app's i18n catalog. Split it:

- **Data strings** (a month name, `12 of 31`) are formatted in JS with `t()` and
  travel in the payload as finished strings — the sync hook has `t`.
- **Chrome** (`configurationDisplayName`, the empty-state line) is hardcoded
  English in Swift. Full localization wants a `Localizable.strings` in the
  extension.

Keep new user-facing text on the JS side of that line where you can.

## Verifying changes

```sh
# extension only — fast, catches all the SwiftUI/WidgetKit errors
xcodebuild -project <App>.xcodeproj -target <App>Widget \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO \
  SYMROOT=/tmp/w/sym OBJROOT=/tmp/w/obj build

# full app — the only thing that compiles the bridge into the app target
xcodebuild -workspace <App>.xcworkspace -scheme <App> \
  -sdk iphonesimulator -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

**Traps in verifying — each of these has produced a false result:**

- **Never pipe `xcodebuild` through `head`.** It closes the pipe, SIGPIPEs the
  build, and you lose the `** BUILD SUCCEEDED/FAILED **` line — a *failed* build
  reads as inconclusive. Redirect to a log file and grep the file.
- **`echo` at the end of a pipeline masks the exit code.**
  `xcodebuild … | grep …; echo done` exits 0 no matter what. Capture `$?` from
  xcodebuild itself.
- **`nm` / `otool` / `strings` on the built app binary prove nothing** about
  whether a class made it in. All three come back empty for a class that is
  unquestionably present. To know whether an object was linked, grep the link
  file list:

  ```sh
  grep WidgetBridge \
    "$DERIVED/Intermediates.noindex/<App>.build/Debug-iphonesimulator/<App>.build/Objects-normal/arm64/<App>.LinkFileList"
  ```

  And confirm embedding with `ls <App>.app/PlugIns/`.
- **Always run a control** when a check comes back negative. A check that cannot
  detect a thing you know is present is not evidence of absence.

### What a build cannot tell you

Two things need an actual simulator or device run:

1. **That `NativeModules.WidgetBridge` resolves under bridgeless.**
   `RCT_EXTERN_MODULE` on an app-target class should come through the TurboModule
   interop layer. If it does not, the adapter's `supported` flag is `false` and
   the whole sync no-ops **silently** — check it deliberately, do not infer it
   from the absence of errors.
2. **App Group provisioning.** Until the group exists on the signing account,
   publishes throw and the widget sits on its empty state.

Widget Swift changes need a full app run, not a Metro reload — there is no JS in
the extension. See `verify` for driving the simulator.

## Danger zone — never do

- Never reimplement the app's visuals in Swift when a published snapshot will do.
- Never let the group id drift between the two entitlements files and the Swift
  constant — writes throw and the widget silently stays empty.
- Never hand-edit `project.pbxproj`.
- Never add a **required** field to the payload struct — older app builds' payloads
  stop decoding and the widget goes blank.
- Never use async Skia hooks (`useImage`, `useFont`) in the offscreen render.
- Never write a second publish hook — racing publishers clobber one payload file.
- Never trust `nm`/`otool`/`strings` as evidence a class was or was not linked.
- Never conclude a widget is broken from one appearance toggle without a rebuild.

## Definition of done

- [ ] Extension target builds standalone **and** the full app builds.
- [ ] Group id identical in both entitlements files and the Swift constant.
- [ ] New payload fields are optional on both sides.
- [ ] Widget verified on a simulator, not inferred from a green build.
- [ ] Both appearances checked, with a delete-and-reinstall between toggles.
- [ ] The architectural choice is recorded in an ADR if this is the first widget.
