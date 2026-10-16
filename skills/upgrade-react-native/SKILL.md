---
name: upgrade-react-native
description: >
  Plan and carry out a React Native version upgrade (for example 0.87 → 0.88)
  in an app or a template repo: read the release notes and the Upgrade Helper
  diff, find the native libraries whose peer ranges block the new version,
  apply the native template changes (SceneDelegate, Info.plist, pbxproj), get
  CocoaPods onto the new prebuilt core, and verify both platforms build and run.
  Use when the user says "upgrade React Native", "bump RN to 0.xx", "plan the
  RN upgrade", "use the upgrade helper", or "a new RN release is out"; when a
  build fails right after an RN bump with Swift errors on new APIs, "extra
  argument 'connectionOptions'", a quarantined package, or an NDK error; or
  before editing react-native, react, or @react-native/* versions in
  package.json.
---

# Upgrading React Native

An RN upgrade is three jobs that fail in different places: **JS dependencies**
(version bumps, peer ranges), **native template changes** (the diff between two
fresh apps), and **native toolchain state** (pods, Gemfile, Xcode, NDK). The
version bump is the easy part. Most of the time goes into the third job, and its
failures do not point back to the upgrade.

Work on a branch. Commit each job separately, so a bisect can tell them apart.

## Phase 1 — plan from the sources, not from memory

**Release notes.** The repository is `react/react-native`:

```sh
gh release view v0.88.0 --repo react/react-native --json body -q .body > rel.md
```

Read the **Changed**, **Deprecated**, **Removed** and **Breaking** sections.
For each API they name, grep the app's `src/`, `index.js`, `babel.config.js` and
`metro.config.js`. Most items do not apply — record which ones you checked, so
the plan says why it skips them.

**The native diff.** The Upgrade Helper reads
`react-native-community/rn-diff-purge`, which has one branch per release
(`release/0.88.0`). The final release often arrives there a few days after the
GitHub release. List what exists:

```sh
gh api 'repos/react-native-community/rn-diff-purge/branches?per_page=100' --paginate \
  -q '.[].name' | grep -E 'release/0\.(87|88)'
```

Do not trust the GitHub compare API on these branches — each release branch is
regenerated, so the compare shows every file as changed. Clone both branches
and diff them:

```sh
git clone -q --depth 1 -b release/0.87.0 https://github.com/react-native-community/rn-diff-purge a
git clone -q --depth 1 -b release/0.88.0 https://github.com/react-native-community/rn-diff-purge b
diff -rq -x .git a/RnDiffApp b/RnDiffApp      # the file list
diff -ruN -x .git a/RnDiffApp b/RnDiffApp     # the real diff
```

If only an RC branch exists, diff against the newest RC. Then confirm that the
RC and the final release differ only in version strings, in the community
template repo:

```sh
git clone -q https://github.com/react-native-community/template t
git -C t tag | grep 0.88.0                     # e.g. 0.88.0-rc.6-678415f, 0.88.0
git -C t diff --stat 0.88.0-rc.6-678415f 0.88.0
```

**Peer ranges of native libraries.** A library with `"react-native": "*"` does
not block the upgrade. A library with a closed range does:

```sh
npm view react-native-reanimated@<installed> peerDependencies --json
npm view react-native-reanimated peerDependencies version --json   # latest
```

Reanimated and Worklets pin RN ranges and pin each other
(`react-native-worklets: 0.13.x`), so bump them together. Read their release
notes for removed APIs before the bump.

**Publish dates.** Check them before you pin anything — see the Yarn age gate
below.

Write the plan as a table of the upstream file changes with a status for each:
update, add, already present, or not applicable.

## Phase 2 — JS dependencies

Bump `react-native`, `react`, `react-test-renderer` and every `@react-native/*`
package to the versions in the upstream `package.json`. Then bump the blocking
native libraries. Run the install from the app directory and check
`yarn -v` first: a Yarn 1 run in a directory without `packageManager` prints
`Saved lockfile` and rewrites that directory's `yarn.lock` in v1 format.

### The Yarn age gate

Yarn 4 can refuse package versions younger than `npmMinimalAgeGate` minutes:

```sh
yarn config get npmMinimalAgeGate                 # 1440 = one day
npm view <pkg> time --json | grep '"<version>"'   # publish time, UTC
```

A version that is too new fails `yarn install --immutable` with:

```
YN0016: │ <pkg>@npm:<version>: All versions satisfying "<version>" are quarantined
```

Do not lower the gate. It is a supply-chain control. Pin the newest version
that is older than the gate. A plain `yarn install` can look green while
`node_modules` keeps the **old** version, so always finish with
`yarn install --immutable`.

## Phase 3 — native template changes

Apply the diff from Phase 1 file by file. Do not copy upstream files over the
app's files: the app has its own additions (splash, fonts, extra targets).

### iOS: the SceneDelegate start (RN 0.88)

From 0.88, the upstream template starts React Native from a `SceneDelegate`, and
`AppDelegate` only returns `true`. The 0.88 release is non-breaking, so the old
`AppDelegate` start still works. Move to the scene start anyway, so the app
matches a fresh init. Upstream source:
`rn-diff-purge` `release/0.88.0`, `RnDiffApp/ios/RnDiffApp/SceneDelegate.swift`:

```swift
class SceneDelegate: RCTDefaultReactNativeFactoryDelegate, UIWindowSceneDelegate {
  var window: UIWindow?
  var reactNativeFactory: RCTReactNativeFactory?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }

    dependencyProvider = RCTAppDependencyProvider()
    reactNativeFactory = RCTReactNativeFactory(delegate: self)
    window = UIWindow(windowScene: windowScene)

    reactNativeFactory?.startReactNative(
      withModuleName: "RnDiffApp",
      in: window,
      connectionOptions: connectionOptions
    )
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    RCTLinkingManager.scene(scene, openURLContexts: URLContexts)
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    RCTLinkingManager.scene(scene, continue: userActivity)
  }
  // bundleURL() override as in the old ReactNativeDelegate
}
```

(Upstream also sets a `RCTDevMenuConfiguration` under `#if DEBUG`; copy it.)

- **Move every override** from the old `ReactNativeDelegate` class into
  `SceneDelegate`: `bundleURL()`, `customize(_:)` (the bootsplash
  `initWithStoryboard` call lives there — see `bootsplash`), and any others.
  The module name is the app's, not `RnDiffApp`.
- Put `SceneDelegate.swift` in the **same directory and Xcode group** as the
  existing `AppDelegate.swift`. The app may not use the upstream layout.
- `Info.plist`: add the `UIApplicationSceneManifest` dictionary with one
  configuration whose `UISceneDelegateClassName` is
  `$(PRODUCT_MODULE_NAME).SceneDelegate`. Validate with `plutil -lint`.
- `project.pbxproj` needs **four** entries: a `PBXBuildFile`, a
  `PBXFileReference`, a child in the group, and a line in the app target's
  Sources phase. Copy the shape of the `AppDelegate.swift` entries, with two new
  24-hex ids that do not occur in the file yet (`grep -c <id>` returns 0).
  Validate with `plutil -lint`.
- Deep links now arrive through `scene(_:openURLContexts:)` and
  `scene(_:continue:)`. Move any code from `application(_:open:options:)` and
  `application(_:continue:restorationHandler:)`.
- If the project keeps ADRs, record the move: it changes native startup.

### Settings that the old template left behind

Compare these in the app's `project.pbxproj` with upstream. Older projects
keep values from the year they were created:

- `IPHONEOS_DEPLOYMENT_TARGET` on the app target (upstream: `15.1`).
- `OTHER_LDFLAGS` (upstream: `"$(inherited)", "-ObjC", "-lc++"` only).

Xcode 27 makes both a hard build error. The exact messages and fixes are in the
`xcode-cloud` skill, `references/failure-catalogue.md`.

## Phase 4 — native toolchain

### CocoaPods keeps the old prebuilt core

RN 0.86+ ships the core as a prebuilt pod. `Podfile.lock` pins
`React-Core-prebuilt` and `ReactNativeDependencies` by version, so after the
bump, `pod install` can keep the **old** prebuilt headers. The Swift build then
fails on APIs that only the new version has:

```
SceneDelegate.swift: error: extra argument 'connectionOptions' in call
SceneDelegate.swift: error: type 'RCTLinkingManager' has no member 'scene'
```

After you delete `Pods/`, CocoaPods says it outright:
`It seems like you've changed the version of the dependency
'React-Core-prebuilt'`. The fix:

```sh
cd ios && bundle exec pod update React-Core-prebuilt ReactNativeDependencies --no-repo-update
grep -E '  - (React-Core-prebuilt|ReactNativeDependencies) \(' Podfile.lock   # new version
```

Then check that every autolinked pod in `Podfile.lock` has the version that is
in `node_modules`. A mismatch means an install did not do what you think:

```sh
grep -E '^  - [A-Za-z-]+ \([0-9]' ios/Podfile.lock     # compare with:
node -p "require('<npm-name>/package.json').version"
```

### Gemfile.lock

Run `bundle install` and read the `Gemfile.lock` diff before you commit it.
Bundler re-resolves gems that the local Ruby cannot use, and it adds the local
platform. Known case: `CFPropertyList` 3.0.9 declares
`required_ruby_version < 3.2`, so on Ruby 3.2 or later Bundler resolves 3.0.8.
Keep 3.0.8. Check a gem's Ruby range with:

```sh
curl -s https://rubygems.org/api/v2/rubygems/<gem>/versions/<version>.json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['ruby_version'])"
```

Also compare the locked gems with `.ruby-version`. `activesupport` 7.2 needs
Ruby 3.1 or later, so a `.ruby-version` below that cannot install the lockfile.

### Android NDK

```
[CXX1101] NDK at ~/Library/Android/sdk/ndk/<version> did not have a source.properties file
```

An earlier NDK install stopped before it finished; the directory holds only
`.installer/`. Libraries that do not set `ndkVersion` use AGP's default NDK, so
this can appear for a version the app never names. Delete that one version
directory and build again; Gradle installs it.

### Disk space

A full iOS debug build output is a few GB, and an all-ABI Android build is more.
Check `df -h` before the builds. To verify Android with less space, build one
ABI:

```sh
./gradlew assembleDebug -PreactNativeArchitectures=arm64-v8a
```

## Phase 5 — verify

1. `yarn install --immutable`, then the repo's lint, typecheck and unit tests
   (see `validate-change`).
2. `bundle install`, then `pod install` — no errors, prebuilt core on the new
   version.
3. iOS build. Use a simulator **id** as the destination, because two simulators
   can have the same name:

   ```sh
   xcrun simctl list devices available | grep 'iPhone'
   xcodebuild -workspace ios/<App>.xcworkspace -scheme <App> -configuration Debug \
     -sdk iphonesimulator -destination 'id=<UDID>' -derivedDataPath ios/build build
   ```

   In a pipeline, `set -o pipefail` first, or `| grep` hides the exit code.
4. Android build.
5. Run the app (see `verify`): splash shows and hides, first screen renders, both
   appearances, a deep link if the app has one.
6. **Template repos only:** generate an app from a packed tarball. A
   `file://<repo dir>` template makes npm link the working tree, and the CLI
   then fails with `EISDIR` on copied `node_modules` and `Pods`:

   ```sh
   T=$(npm pack --silent --pack-destination /tmp)
   npx @react-native-community/cli@<version> init Sample --template file:///tmp/$T \
     --skip-install --skip-git-init --install-pods false
   ```

   Check that the placeholder name is replaced in every new native file
   (`SceneDelegate.swift` holds the module name).
7. Update every document that states the RN or React version.
8. Delete your build output (`ios/build/Build`, `android/app/build`) if the disk
   is short. Keep `ios/build/generated` and any `*-facades` directories that
   `Podfile.lock` points to.

## Danger zone

- Never copy upstream native files over the app's files — merge them.
- Never lower or bypass the Yarn age gate to get a fresh release in.
- Never commit a `Gemfile.lock` or `Podfile.lock` without reading its diff.
- Never trust a green `pod install` after a bump — check the prebuilt version.
- Never conclude "RN 0.xx breaks the build" before you compare the app's old
  settings (deployment target, linker flags) with upstream.
- Never test a template repo with `file://<repo dir>`; use the packed tarball.

## Definition of done

- [ ] Plan lists every upstream file change with a status, and the release-note
      items checked against the code.
- [ ] `yarn install --immutable` passes; no quarantined versions pinned.
- [ ] `Podfile.lock` has the new prebuilt core, and pod versions match
      `node_modules`.
- [ ] iOS and Android builds pass; the app ran on a simulator.
- [ ] JS deps, native template changes, and toolchain fixes are separate commits.
