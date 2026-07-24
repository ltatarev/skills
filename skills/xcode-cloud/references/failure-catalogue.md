# Failure catalogue

Symptom-indexed. Every entry here was paid for by a failed build — each one
records the log line you actually see, what it really means, and the fix.

**This file is append-only and shared across projects.** When you diagnose a new
Xcode Cloud failure whose cause is *not* specific to one repo, add an entry in
the same shape. See "Recording what you learn" in `SKILL.md` for which tier a
learning belongs in.

Grep it by the literal error text before theorising — several of these look like
something else entirely.

---

## `Unable to load contents of file list: '/Target Support Files/…'`

```
Unable to load contents of file list:
  '/Target Support Files/Pods-<App>/Pods-<App>-frameworks-Release-output-files.xcfilelist'
```

**Read the leading slash.** Those paths are written in `project.pbxproj` as
`${PODS_ROOT}/Target Support Files/…`, so an absolute path starting at
`/Target Support Files` means `PODS_ROOT` expanded to an empty string. Two
causes, and only two:

1. Pods were never installed — no post-clone script, or it failed, or it is not
   executable.
2. The workflow builds `<App>.xcodeproj` instead of `<App>.xcworkspace`, so
   `Pods-<App>.release.xcconfig` never gets applied.

Cause 2 produces an identical error with pods installed perfectly. **Check it
first** — it is one dropdown in the workflow, and the log gives you no hint
which of the two you are looking at.

## The post-clone script never ran at all

No output from it anywhere in the log, and the archive fails as though it does
not exist. Three requirements, all silent when unmet:

- The directory must be named `ci_scripts` and must sit **next to the workspace**
  (`ios/ci_scripts/` for a standard RN layout), not at the repo root.
- The file must be committed **executable** (`git update-index --chmod=+x`). A
  non-executable `ci_post_clone.sh` is skipped without a word, which looks
  exactly like the file not being there.
- The commit must be **pushed**. Xcode Cloud only ever builds pushed commits;
  a local commit does nothing.

## `node: command not found` in "Bundle React Native code and images"

Post-clone installed node fine and printed a version, then the build phase
cannot find it. `ios/.xcode.env` resolves node with `command -v node`, and
Homebrew's `node@NN` formulae are **keg-only** — not on the PATH of the shell
that runs the build phase. Environment exported in post-clone does not reach
`xcodebuild`; it runs in a separate process.

Write the absolute path to a file instead:

```sh
printf 'export NODE_BINARY=%s\n' "$(command -v node)" > "$IOS_DIR/.xcode.env.local"
```

Generalise the lesson: **anything the build phases need must be written to a
file, never exported.**

## `corepack: command not found` during install

```
ci_post_clone.sh: line 52: corepack: command not found
Command exited with non-zero exit-code: 127
```

Node installed cleanly and printed its version two lines earlier, which is what
makes this read as a PATH problem. It is not. **Node 25 removed corepack from
the distribution** — deprecated in 24, unbundled in 25 — so any build image on
node 25 or newer has node, npm, and no corepack at all. A laptop that still
works is one that got corepack from somewhere else; on Homebrew that is the
separate `corepack` formula, which is easy to forget you ever installed.

Install it as its own formula alongside node:

```sh
brew install "$NODE_FORMULA" corepack cocoapods
```

**Both the install and `corepack enable` are load-bearing.** The formula links
only `corepack` itself — the `yarn` and `pnpm` shims are created by
`corepack enable`, so installing the formula and then calling `yarn` directly
still fails.

Do not reach for `brew install yarn` instead: that formula is yarn **1.x**, and
a repo with `packageManager: yarn@4.x` needs corepack to fetch the pinned
version. If corepack itself ever goes away, the escape hatch is committing a
yarn release under `.yarn/releases/` and setting `yarnPath` in `.yarnrc.yml`,
which removes the dependency entirely.

## `Error: async hook stack has become corrupted` during install

```
Error: async hook stack has become corrupted (actual: 4, expected: 4)
  node::worker::Worker::Run …
  node::worker::MessagePort::OnMessage …
```

Yarn extracts archives on worker threads by default (`taskPoolMode: workers`),
which walks into an `async_hooks` corruption bug in node 22 and kills the
install partway through the fetch step. Nothing in the project causes it — which
is why a laptop on a newer node never reproduces it.

`YARN_TASK_POOL_MODE=async` moves that work onto the event loop: a few seconds
slower, and it does not crash. Keep it in the CI script rather than
`.yarnrc.yml` so local installs keep the faster path. The other cure is a newer
node — worth retesting whenever the pinned version moves.

## `curl: (35) Recv failure` inside `pod install`

```
[ReactNativeDependencies] Cache miss: downloading reactnative-dependencies-<ver>-release.tar.gz
curl: (35) Recv failure: Connection reset by peer
[!] Invalid `Podfile` file: [ReactNativeDependencies] Failed to download … Aborting.
```

For RN 0.86+, `pod install` also downloads **four** prebuilt tarballs from Maven
Central, each with a bare single-shot `curl` and no `--retry`. One connection
reset on Apple's runner kills the whole archive.

The Rosetta2 / `arch -arm64` advice CocoaPods prints underneath is a **red
herring** — the real line is the `curl: (35)`.

They come from two different scripts, which is the trap: fixing one leaves the
other.

| Artifact | Script | Cache file |
| --- | --- | --- |
| `dependencies`, debug + release | `rndependencies.rb` | `reactnative-dependencies-<ver>-<type>.tar.gz` |
| `core`, debug + release | `rncore.rb` | `reactnative-core-<ver>-<type>.tar.gz` |

The `core` pair is loaded later, from `React-Core-prebuilt.podspec`, so it fails
*after* codegen and the log looks much further along:

```
[ReactNativeCore] Cache miss: downloading reactnative-core-<ver>-debug.tar.gz
[!] Failed to load 'React-Core-prebuilt' podspec:
```

Both check the same shared cache first (`~/Library/Caches/ReactNative/`, SHA1
verified against the Maven `.sha1` sibling), so seeding all four before
`pod install` with a retrying curl fixes both at once — see
`ci_post_clone.sh`. One tarball landing while the next resets is the classic
signature.

This is a resilience layer, **not a guaranteed fix**: if Maven is unreachable
for both the prefetch retries and pod install, re-running the build is still the
move. If a future RN adds a fifth artifact, add one entry to the `for artifact
in` loop — URL and cache filename are both `reactnative-<artifact>-<ver>-<type>`.

## `bigdecimal` fails to compile / `rb_complex_real` redeclaration

```
./missing.h:61:1: error: static declaration of 'rb_complex_real' follows non-static declaration
```

Installing CocoaPods as a **gem** means compiling native extensions on the build
machine, and `bigdecimal` (via `activesupport`, via `cocoapods`) will not build
there.

The mechanism: `extconf.rb` probes for `rb_complex_real` with `have_func`. The
probe answers `no`, so `missing.h` supplies its own `static inline` version — but
Ruby 3.3's headers already declare it, and the two collide. Every `bigdecimal`
release carries that same `#ifndef HAVE_RB_COMPLEX_REAL` fallback, so
**downgrading does not help.** The probe fails because the image already has one
Ruby linked and a second keg-only one installed alongside it: it compiles
against one and resolves symbols against the other. Setting `LDFLAGS`/`CPPFLAGS`
per Homebrew's caveats does not fix it.

`brew install cocoapods` pours a bottle and invokes no compiler, so the failure
mode is structurally impossible. **What you give up is less than it looks** —
`Podfile.lock` pins every pod by exact version and checksum and `pod install`
honours it regardless of which CocoaPods runs. Only the tool version floats.
(Observed on one upgrade, 1.15.2 → 1.17.0: two recomputed podspec checksums, the
`COCOAPODS:` stamp, and eight lines of empty `inputPaths`/`outputPaths` 1.17 no
longer emits. Zero pod versions moved.)

Use the same bottle locally so both sides run the same tool. Note that
`brew install cocoapods` pulls in Homebrew's `ruby` as a dependency, and it takes
precedence over rbenv shims — so `ruby` in the repo may not be the version
`.ruby-version` names.

## bundler installs different gem versions than the lockfile

If you keep bundler anyway: the builders are **x86_64** and a laptop-generated
`Gemfile.lock` lists only `arm64-darwin-*`. Bundler silently re-resolves the
entire dependency graph instead of installing what is locked.

```sh
bundle lock --add-platform x86_64-darwin
```

## Exit 65 with no `error:` anywhere in the log

Every target reads green, `grep` for `ld: error`, `Undefined symbols`,
`framework not found` and `clang: error` all come back empty, and the archive
still fails. The reason lives **only in the result bundle**, which Xcode Cloud
offers for download beside the logs:

```bash
xcrun xcresulttool get build-results --path <build>.xcresult
```

```json
"errorCount": 2,
"errors": [
  { "issueType": "Error", "message": "Warning: ", "targetName": "<App>" },
  { "issueType": "Uncategorized",
    "message": "Command Ld emitted errors but did not return a nonzero exit code to indicate failure" }
]
```

Note the first: an **empty** message, `"Warning: "`, classified as an Error. That
is Xcode's linker-diagnostic parser tripping over `ld`'s output and emitting a
malformed entry. `ld` exits 0, the build system sees an error-classified
diagnostic from a command claiming success, refuses to trust it, and fails the
archive — while the same bundle records `"status": "succeeded"` alongside.

What fed the parser was **volume**: thousands of copies of one warning.

```
ld: warning: object file (…libskia.a(…)) was built for newer iOS version (14.0)
    than being linked (12.4)
```

The app target set no `IPHONEOS_DEPLOYMENT_TARGET` and inherited a stale
template value from the project level, while the `Podfile` pins pods to
`min_ios_version_supported` (find the real number in
`node_modules/react-native/scripts/cocoapods/helpers.rb`). Every pod compiled at
one target, every one warned when linked at the other.

**Fix:** set both app configurations to `min_ios_version_supported`, and keep
them in step on every RN bump. Health check — the count, since the failure is
driven by volume:

```bash
grep -c "ld: warning" <archive>.log
```

One is expected (`ignoring duplicate libraries: '-lc++'`, because the pods
xcconfig and the target both pass it, exactly as upstream's template does).
Thousands means the deployment targets have drifted apart again.

This reproduces on **some Xcodes only** — 26.5 on the build machines failed on it
twice while 26.6 locally linked the identical warnings and archived fine. **A
green local archive does not clear it.**

Reach for `xcresulttool` whenever the text log looks entirely green. It is also
the fastest way to read *any* archive failure: it lists `errorCount` and every
issue as JSON instead of leaving you to grep eight megabytes.

## `-ld64` / `-ld_classic` deprecation warnings

`-ld64` in `OTHER_LDFLAGS` selects the classic linker and draws
`ld: warning: -ld_classic is deprecated and will be removed in a future
release` — a contributor to the volume problem above.

It was never yours and is no longer React Native's. Xcode 15 shipped a new
linker (`ld_prime`) that broke a lot of projects, so the RN 0.72-era template
pushed `-ld_classic` — spelled `-ld64` during the Xcode 15 betas — into
`OTHER_LDFLAGS`. Upstream has dropped it; the current template ships plain
`"$(inherited)", "-ObjC", "-lc++"`. It survives in older projects only because it
was copied in at init and never revisited.

**Do not add it back to silence a linker problem.** Apple has said it will be
removed outright, and on a modern Xcode it buys nothing.

## Archive is green, TestFlight is empty

A green Archive **does not upload anything**. In order:

1. Workflow → **Archive** action → *Deployment Preparation* must be
   **"App Store Connect and TestFlight"**. Set to `Development` or `Testing`, the
   archive is only a downloadable artifact.
2. Add **Post-Action → TestFlight Internal Testing** and pick a tester group.
3. The app record for the bundle id must already exist in App Store Connect.
   Xcode Cloud will not create it.
4. If the upload succeeded but the build never appears, Apple emails the reason.
5. Processing is normally 5–15 minutes. Longer than an hour with no email means
   it was never uploaded.

Fast check: open the finished build and look at its artifacts. An `.xcarchive`
with no `.ipa` means nothing was sent.

## The first archive after switching to TestFlight fails

Expect this. Under `Development` the archive signs ad-hoc and never checks
entitlements; under TestFlight it signs for **distribution**, and everything the
app claims has to exist on the account behind the signing team. `xcodebuild`
reports that as a bare exit code 65 — the reason is in the `error:` lines further
down, not in the exit code. (If there is no `error:` line at all, see the exit-65
entry above; it is a different animal.)

For each capability the app and its extensions claim, four things must exist —
using App Groups as the worked example:

| What | Where |
| --- | --- |
| The app group itself | Identifiers → App Groups |
| The app's App ID assigned to it | Identifiers → App IDs → App Groups |
| Each extension's App ID assigned to it | same — the extension needs it too |
| An app record for the bundle id | App Store Connect |

**Enabling a capability is not the same as assigning the App ID to the group.** A
profile built from a capability with no group assigned still fails. Xcode Cloud
only consumes profiles, it never creates capabilities — opening the workspace in
Xcode once with automatic signing does create them, which is why that is the
quick repair.

## Build rejected for a duplicate build number

App Store Connect rejects any build reusing a `CFBundleVersion` under the same
marketing version. The RN template hardcodes `CURRENT_PROJECT_VERSION = 1` in
every configuration, which survives exactly one upload. Stamp `$CI_BUILD_NUMBER`
over all of them in `ci_pre_xcodebuild.sh`.

## Every build lands in "Missing Compliance"

Declare `ITSAppUsesNonExemptEncryption` in the app's `Info.plist`. Without it,
each build sits in "Missing Compliance" and cannot reach testers until the
question is answered by hand, one build at a time. `false` is correct for an app
using only standard HTTPS, which is exempt — revisit if it ever ships its own
cryptography.
