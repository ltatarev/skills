# Build machine facts

What an Xcode Cloud runner actually gives you, **verified from build logs rather
than from documentation**. Apple does not publish most of this and changes it
without notice, so every row carries the date it was observed.

## How to use this file

- Treat a row older than a few months as a **hypothesis**, not a fact. Confirm it
  in the current build log before designing around it.
- When a build log contradicts a row, **update the row and move the old value
  into its History line** — do not silently overwrite. Knowing that CocoaPods
  went 1.17.0 → 1.19 is worth more than knowing only the current number.
- When you observe something not listed, add a row. Cite the log line that
  proves it.

A cheap way to harvest all of this in one build — drop it at the top of
`ci_post_clone.sh`, read the log, then take it out again:

```sh
echo "arch=$(uname -m) brew=$(brew --prefix) xcode=$(xcodebuild -version | tr '\n' ' ')"
echo "pwd=$PWD repo=$CI_PRIMARY_REPOSITORY_PATH"
echo "ruby=$(ruby -v) pod=$(pod --version 2>/dev/null || echo absent) node=$(command -v node || echo absent)"
env | grep '^CI_' | sort
```

---

## Environment

_Observed 24.07.2026 · Xcode 26.5 · RN 0.86_

| Thing | Reality |
| --- | --- |
| Architecture | **x86_64** — `/usr/local/Cellar`, not `/opt/homebrew` |
| Homebrew | present; its `ruby` formula is **already installed and linked** |
| Node | **absent** — must be installed. `brew install node@NN` for the *current* major resolves through an alias to the unversioned `node`, which is **not** keg-only; only older majors are real keg-only formulae |
| corepack | **absent, and node does not supply it** — node 25 dropped it from the distribution. It is a separate Homebrew formula, and that formula links only `corepack`; `yarn`/`pnpm` shims appear only after `corepack enable` |
| CocoaPods | **1.17.0 preinstalled** — `brew install cocoapods` is a no-op, worth keeping so the script does not depend on the preinstall |
| Caching | **none** — every run reinstalls everything, ~2–3 min |
| Working directory | the script starts in `ios/ci_scripts`, **not** the repo root |
| Repo path | `$CI_PRIMARY_REPOSITORY_PATH` = `/Volumes/workspace/repository` |
| Xcode | 26.5 (a *newer* Xcode locally is normal — see the exit-65 entry in `failure-catalogue.md`) |

_History: nothing superseded yet. The node and corepack rows were sharpened
24.07.2026 after a build died on `corepack: command not found` — the earlier
"Node absent" row was true but incomplete, which was enough to cost a build._

## Rules that follow from the environment

These are structural, not version-dependent — they have held across every
observation so far.

1. **`ci_scripts/` must sit next to the workspace**, and every script must be
   committed executable. A non-executable script is skipped silently.
2. **Environment exported in post-clone does not reach `xcodebuild`.** It runs in
   a separate process. Anything the build phases need must be written to a file.
3. **Only pushed commits build.** Local commits do nothing.
4. **No caching between runs.** Do not design around a warm cache; do make each
   network fetch retry.
5. **The runner arch is not your laptop's arch.** Anything platform-locked —
   `Gemfile.lock` platforms, prebuilt binaries, bottles — has to account for
   x86_64.

## Environment variables worth knowing

| Variable | Use |
| --- | --- |
| `CI_PRIMARY_REPOSITORY_PATH` | repo root; the only reliable way to find it |
| `CI_BUILD_NUMBER` | per-build counter — stamp it as `CURRENT_PROJECT_VERSION` |
| `CI_XCODEBUILD_ACTION` | `archive`, `build-for-testing`, … — branch on it if a step is only worth running for archives |
| `CI_BRANCH`, `CI_TAG`, `CI_PULL_REQUEST_NUMBER` | what triggered this run |
| `CI_WORKFLOW` | the workflow's name; useful when several share one script |

Guard every one with `${VAR:-}` under `set -u` — they are absent when the script
is run locally, and a script that explodes locally is a script nobody tests.
