---
name: xcode-cloud
description: >
  Set up, debug and maintain Xcode Cloud CI for a React Native iOS app — the
  ci_post_clone.sh / ci_pre_xcodebuild.sh scripts that install node, pods and
  the RN prebuilt tarballs, the workflow settings, and the App Store Connect
  prerequisites for TestFlight. Use when the user asks to set up Xcode Cloud,
  add CI to an iOS app, get builds into TestFlight, or fix a failing cloud
  build; when an archive fails with "Unable to load contents of file list",
  "node: command not found", a curl error inside pod install, a bigdecimal or
  bundler failure, or a bare exit 65; when a green archive never reaches
  TestFlight; or before touching anything under ios/ci_scripts/, .xcode.env,
  Podfile, or Gemfile. Also use to record a newly diagnosed cloud build failure
  so it is not re-derived next time.
---

# Xcode Cloud for a React Native app

Xcode Cloud clones the repo and **nothing else**. `node_modules/` and `Pods/`
are both gitignored, so a fresh clone has no JavaScript and no pods — the
archive has to install them itself before `xcodebuild` ever runs. That is the
whole job of `ci_post_clone.sh`, and nearly every "Xcode Cloud is broken"
report is really that job failing in one of a dozen documented ways.

This skill carries those ways. **`references/failure-catalogue.md` is the
highest-value file here** — grep it for the literal error text before theorising
about any failure.

| File | What it is |
| --- | --- |
| `references/ci_post_clone.sh` | The install script. Template; three lines to check per project. |
| `references/ci_pre_xcodebuild.sh` | Build-number stamping. Generic as written. |
| `references/failure-catalogue.md` | Symptom → real cause → fix. Append-only. |
| `references/build-machine-facts.md` | What the runner actually provides, with observation dates. |
| `references/project-memory.md` | The per-project doc skeleton + the hook that keeps it current. |

## Phase 0 — ground yourself in the repo

Never write these scripts from the template alone. Five minutes here saves a
build, and each failed build costs 10–20 minutes of round trip.

```bash
ls -d ios/*.xcworkspace ios/*.xcodeproj ios/ci_scripts 2>/dev/null
ls ios/*.xcodeproj/xcshareddata/xcschemes/     # scheme shared? empty = not shared
node -p "require('./package.json').dependencies['react-native']"
cat .nvmrc 2>/dev/null; node -p "require('./package.json').engines?.node ?? 'no engines'"
ls yarn.lock package-lock.json pnpm-lock.yaml 2>/dev/null
git check-ignore -v ios/Pods node_modules ios/.xcode.env.local
grep -c "CURRENT_PROJECT_VERSION" ios/*.xcodeproj/project.pbxproj
grep -rn "IPHONEOS_DEPLOYMENT_TARGET" ios/*.xcodeproj/project.pbxproj | sort -u
grep -rln "PRODUCT_BUNDLE_IDENTIFIER" ios/*.xcodeproj/project.pbxproj >/dev/null \
  && grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*' ios/*.xcodeproj/project.pbxproj | sort -u
ls ios/*/*.entitlements ios/*.entitlements 2>/dev/null   # capabilities to provision
```

What each answer changes:

| Finding | Consequence |
| --- | --- |
| No `.xcworkspace` | Pods have never been installed here; `pod install` locally first. |
| Scheme not shared | Xcode Cloud cannot see it. Share it in Xcode and commit `xcshareddata/`. |
| Package manager | Swap the install block in post-clone (yarn / npm ci / pnpm). |
| `.nvmrc` / `engines.node` | Sets `NODE_FORMULA`. Mismatching CI and local node is a real source of "works on my machine". |
| RN < 0.86 | No prebuilt tarballs — the prefetch loop is a harmless no-op; leave it. |
| `Pods/` **not** gitignored | Rare, but then post-clone needs no `pod install`. Check before assuming. |
| Extra targets (widget, share extension) | Each needs its own build number and its own App ID assignments. |
| `IPHONEOS_DEPLOYMENT_TARGET` absent or low | See the exit-65 entry in the catalogue. Fix it now, not after it bites. |

Read `references/build-machine-facts.md` before designing anything around the
runner's environment — and check the observation dates in it.

## Phase 1 — the scripts

Write `references/ci_post_clone.sh` and `references/ci_pre_xcodebuild.sh` into
`ios/ci_scripts/`, adapted from Phase 0's findings — read both in full first;
each carries a `TEMPLATE` header naming exactly what to check.

```bash
mkdir -p ios/ci_scripts                                  # before writing them
chmod +x ios/ci_scripts/*.sh                             # after
git add ios/ci_scripts && git update-index --chmod=+x ios/ci_scripts/*.sh
```

**The location and the executable bit are both load-bearing.** `ci_scripts/`
must sit next to the workspace, and a non-executable script is skipped in
silence — indistinguishable in the log from a script that does not exist.
Verify what git actually recorded, not what the filesystem says:

```bash
git ls-files -s ios/ci_scripts   # want mode 100755, not 100644
```

Keep the explanatory comments. They are the local record of why each line
exists, and they are what stops the next person "simplifying" the yarn flag or
the tarball prefetch back out again.

Dry-run locally before pushing. Both scripts are written to work off a checkout
with no CI variables set — post-clone is idempotent, and pre-xcodebuild exits
early with `CI_BUILD_NUMBER` unset:

```bash
bash -n ios/ci_scripts/*.sh                                            # syntax
CI_PRIMARY_REPOSITORY_PATH="$PWD" ios/ci_scripts/ci_pre_xcodebuild.sh  # no-op locally
```

## Phase 2 — project settings

Three edits that are cheap now and expensive after a failed archive:

1. **Deployment target.** Set `IPHONEOS_DEPLOYMENT_TARGET` on every app
   configuration to the same value the Podfile pins pods to
   (`min_ios_version_supported`, resolved in
   `node_modules/react-native/scripts/cocoapods/helpers.rb`). Drift here fails
   archives on some Xcodes and not others.
2. **Export compliance.** Add `ITSAppUsesNonExemptEncryption` to the app's
   `Info.plist` or every build parks in "Missing Compliance".
3. **`OTHER_LDFLAGS` hygiene.** If `-ld64` or `-ld_classic` is in there, it is
   template residue from RN 0.72 — remove it. See the catalogue.

## Phase 3 — the account side (the user's job, not yours)

None of this can be done from the repo, and all of it fails the *first
distribution archive* rather than the ones before it. Hand the user an explicit
list built from Phase 0's entitlements and bundle ids:

- An **app record** in App Store Connect for the app's bundle id. Xcode Cloud
  will not create it.
- For each capability each target claims: the identifier must **exist**, and each
  App ID must be **assigned** to it. Enabling a capability is not the same as
  assigning the App ID — a profile built from a capability with nothing assigned
  still fails.
- Extensions need their own App IDs, with the same assignments as the host.

Quick repair when profiles are wrong: open the workspace in Xcode once with
automatic signing. Xcode creates capabilities; Xcode Cloud only ever consumes
profiles.

## Phase 4 — the workflow

Created in Xcode (Product → Xcode Cloud) or App Store Connect. UI work — walk
the user through it rather than pretending to do it.

- **Build the `.xcworkspace`, never the `.xcodeproj`.** The single most common
  misconfiguration, and it produces an error that looks like missing pods.
- Scheme: the **shared** one from Phase 0.
- Start condition: usually branch changes on the release branch. Note that Xcode
  Cloud only builds **pushed** commits.
- **Files and Folders**, under the branch-changes condition, keeps prose commits
  from burning an archive: set the dropdown to *Don't Start a Build* and add
  `docs/` or equivalent. It excludes, so a commit touching both docs and source
  still builds — it cannot silently swallow a real change, unlike an include
  list. The complement is `ci skip` anywhere in a commit message, which makes
  Xcode Cloud ignore that push entirely and covers the stray files no folder
  condition can.
- Action **Archive**, and *Deployment Preparation* = **App Store Connect and
  TestFlight** if the build is meant to reach testers. `Development` or
  `Testing` produces a downloadable artifact and uploads nothing.
- **Post-Action → TestFlight Internal Testing**, with a tester group. Without
  it, a perfect archive still never appears.

Warn the user that the first archive after switching to TestFlight distribution
often fails where the previous ones passed — it is the first one that checks
entitlements at all. That is expected, and Phase 3 is the fix.

## Phase 5 — install the project's memory

Do this in the same session, not "later". Follow
`references/project-memory.md`: write `docs/xcode-cloud.md` in the project's own
voice, and add the `PostToolUse` hook to the project's `.claude/settings.json`.

The doc is not a copy of this skill. This skill holds what is true of Xcode
Cloud; the doc holds what is true of **this app** — its bundle ids, its
capabilities, its extensions, the workarounds its dependencies forced. Overlap
between the two is drift waiting to happen.

## Phase 6 — first build, then triage

Push, watch the log, and expect the first one to fail. When it does:

1. **Grep the log for the literal error text in
   `references/failure-catalogue.md` before forming any theory.** Most of these
   failures name something other than their cause: the file-list error means the
   wrong build target, the Rosetta advice is a red herring for a network reset,
   and a bare exit 65 with no `error:` line is not a signing problem.
2. If the log reads entirely green and it still failed, download the result
   bundle:
   ```bash
   xcrun xcresulttool get build-results --path <build>.xcresult
   ```
   This is also the fastest way to read *any* archive failure — `errorCount` and
   every issue as JSON, instead of grepping eight megabytes.
3. Fix, push, repeat. Then go to "Recording what you learn".

## Recording what you learn

**This is the part that makes the skill worth keeping.** Every Xcode Cloud
failure is expensive to diagnose and trivial to re-encounter. Whenever you
diagnose one — during setup or years later — write it down before moving on.

Route it by **who else it is true for**:

| The finding is true of… | Goes in | Shape |
| --- | --- | --- |
| this repo only — its bundle ids, capabilities, a dependency's quirk | the project's `docs/xcode-cloud.md` | prose, in that doc's voice |
| Xcode Cloud, the build image, CocoaPods, or RN at some version | `references/failure-catalogue.md` | a new `##` section, same shape as its neighbours |
| what the runner provides | `references/build-machine-facts.md` | update the row **and** its History line; never overwrite silently |
| the install steps themselves | `references/ci_post_clone.sh` (+ this file) | the fix, plus a comment saying what it prevents |

Unclear which? Write it in the project doc and add a one-line pointer in the
catalogue. A duplicated fact is recoverable; a lost one is not.

A catalogue entry is only useful if the next reader can **find it by the symptom
they have**. So: the heading is the error text they will grep for, the first
paragraph is what it actually means, and the fix comes last. Include the
misleading part explicitly — "the Rosetta advice underneath is a red herring"
is often the single most valuable sentence in an entry.

**Where to edit.** `${CLAUDE_PLUGIN_ROOT}` is the *installed* copy of this
plugin and is read-only in practice — edits there are silently discarded on the
next `/plugin marketplace update`. Edit the source checkout instead, then push
and update. If you cannot find the source checkout, ask the user for its path
once; if the project has no access to it at all, put the learning in the
project's `docs/xcode-cloud.md` and tell the user it needs promoting later.

**Say what you changed.** End any session that touched CI with an explicit line:
which file recorded which learning. A silent update to a memory file is
indistinguishable from no update at all.

## Danger zone — never do

- **Never build the `.xcodeproj`.** It fails as though the pods are missing and
  sends you debugging the wrong half of the system.
- **Never commit a CI script non-executable.** Silent skip, no diagnostic.
- **Never `export` something and expect `xcodebuild` to see it.** Separate
  process. Write it to a file.
- **Never install CocoaPods as a gem on the runner** to "match local" — use the
  same bottle on both sides instead. The native extensions do not build there,
  and no amount of version pinning fixes it.
- **Never trust a green local archive** to clear a cloud failure. Different
  Xcode, different arch, different linker behaviour.
- **Never conclude "network flake, just retry"** without checking whether the
  fetch had retries at all. RN's tarball downloads did not.
- **Never delete the explanatory comments from the CI scripts.** They are the
  only thing standing between the next reader and repeating the failure.
- **Never edit the installed plugin copy of this skill.** Edit the source repo.
- **Never bump a fact in `build-machine-facts.md` from memory** — it is only
  worth anything because every row was read off a real build log.

## Definition of done

- [ ] Both scripts committed under `ios/ci_scripts/`, **mode 100755 in git**.
- [ ] Scripts adapted to this repo's package manager, node version and ios path
      — not left as the template.
- [ ] Both run clean locally with no CI variables set.
- [ ] Workflow builds the **workspace** with a **shared** scheme.
- [ ] Deployment Preparation and the TestFlight post-action set, if testers are
      the goal.
- [ ] Account-side prerequisites listed for the user, one line per identifier.
- [ ] `docs/xcode-cloud.md` written in the project's voice, and the hook
      installed **and observed firing**.
- [ ] One archive has gone green and reached TestFlight.
- [ ] Every failure diagnosed on the way there is recorded in the tier its
      lesson belongs to, and the user has been told where.
