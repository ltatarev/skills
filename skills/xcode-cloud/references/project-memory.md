# The project's own memory

Two artefacts, installed once per project. The doc holds what is true of *this*
app; the hook is what stops the doc rotting.

Without both, the next person to touch CI re-derives everything from failed
builds — which is exactly what this skill exists to prevent.

## 1. `docs/xcode-cloud.md`

Written **as prose, in the project's voice**, not as a filled-in form. The
skeleton below is the set of questions it must answer; delete any section the
project genuinely does not have rather than leaving it empty.

The test for every paragraph: *would this have saved a build?* A section that
only restates what the script already says out loud is noise — the script's own
comments carry the local why.

````markdown
# Xcode Cloud — what it takes to archive this app

<One paragraph: what a fresh clone is missing, and therefore what post-clone
has to do. Name the gitignored directories.>

## TL;DR

```sh
ios/ci_scripts/ci_post_clone.sh      # runs automatically, must stay mode 755
ios/ci_scripts/ci_pre_xcodebuild.sh  # ditto
```

<Two sentences on what each one does.>

## What the build machine gives you

<Only the rows that this project depends on. The full table lives in the
skill's build-machine-facts.md — do not copy it wholesale, it will drift.>

## Why <each non-obvious decision in the scripts>

<One section per decision that cost a build: the toolchain source, the yarn
flag, the prefetch, the NODE_BINARY pin. Each says what failed, why, and what
would make the workaround unnecessary later.>

## Workflow settings that matter

- Build the **workspace** (`ios/<App>.xcworkspace`), never the `.xcodeproj`.
- The scheme must be **shared** (checked in under `xcshareddata/xcschemes/`).
- Xcode Cloud only builds **pushed** commits.
- <Deployment Preparation, post-actions, and which branches trigger which
  workflow.>

## Getting a build into TestFlight

<The account-side prerequisites for THIS app: bundle ids, every capability it
claims, every extension, the app record. This is the section people need at
2am — be specific, name the identifiers.>

## The build number

<How CURRENT_PROJECT_VERSION is stamped, how many configurations, and why they
have to move together. Note that MARKETING_VERSION is bumped by hand.>

## Export compliance

<The ITSAppUsesNonExemptEncryption declaration and why it is what it is.>

## Keeping this doc current

<Point at the hook below, and say how to disable it.>
````

## 2. The hook

Goes in the project's `.claude/settings.json`. On any write to a CI-relevant
file it injects a reminder to update the doc in the same turn — a nudge with the
changed path attached, not an automatic edit, because the doc is prose and worth
writing deliberately.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path // .tool_response.filePath // empty' | { read -r f || exit 0; case \"$f\" in */ios/ci_scripts/*|*/Gemfile|*/Gemfile.lock|*/ios/Podfile|*/ios/Podfile.lock|*/ios/.xcode.env*) jq -n --arg f \"$f\" '{hookSpecificOutput:{hookEventName:\"PostToolUse\",additionalContext:($f + \" changed. docs/xcode-cloud.md is the record of how Xcode Cloud builds this app — if this change alters the toolchain, the install steps, the workflow expectations, or documents something newly learned about a failure, update docs/xcode-cloud.md in this same turn. Do nothing if the doc already covers it.\")}}' ;; esac; } 2>/dev/null || true",
            "timeout": 10,
            "statusMessage": "Checking whether the Xcode Cloud doc needs updating"
          }
        ]
      }
    ]
  }
}
```

Adjusting it:

- **The doc path appears twice in the string** — in the reminder text. Change
  both if the doc lives elsewhere.
- **The `case` globs are the trigger set.** Add `*/ios/*.xcodeproj/project.pbxproj`
  if signing or build settings are hand-edited often; leave it out if that file
  churns for unrelated reasons, since a hook that fires constantly gets ignored.
- Adjust `*/ios/*` if the Xcode project is not in `ios/`.
- If the project already has a `PostToolUse` array, **append to it** — do not
  replace the block.

Verify it fires before trusting it: edit `ci_post_clone.sh` (even a comment) and
check that the reminder appears. A hook with a `jq` typo fails silently by
design — `|| true` is there so a broken hook can never block a write.
