# adora-skills

A personal Claude Code plugin marketplace — a single repo that holds reusable
skills so they can be installed across all my projects or globally.

## Structure

```
skills/                           # the repo folder — name is irrelevant to the tooling
├── .claude-plugin/
│   ├── marketplace.json          # the catalog: lists plugins + where to find them
│   └── plugin.json               # this repo IS the plugin (marketplace entry uses "source": "./")
└── skills/
    ├── add-feature/SKILL.md
    ├── bootsplash/                # + references/bootsplash-dark.mjs
    ├── build-ui/SKILL.md
    ├── commit-changes/SKILL.md
    ├── gitmoji/                   # + references/gitmoji.json
    ├── implement-ticket/SKILL.md
    ├── ios-widget/                # + references/add-widget-target.rb
    ├── maintain-skills/SKILL.md
    ├── ticket-shaping/SKILL.md
    ├── truesheet-usage/           # + references/*.md
    ├── unistyles/                 # + references/unistyles.md (full offline docs)
    ├── validate-change/SKILL.md
    ├── verify/SKILL.md
    └── write-tests/SKILL.md
```

## The skills

Ported from the `.claude/skills/` and `.agents/skills/` directories of the
React Native projects, generalized so they read the specifics out of whatever
repo they run in rather than hardcoding one project's paths.

**React Native**

| Skill | What it does |
| ----- | ------------ |
| `build-ui` | Authoring JSX to the house standard: Unistyles v3, theme tokens, the shared `theme/ui` kit, i18n + a11y, toast, worklets. |
| `add-feature` | Scaffolding or extending a `src/modules/` module: anatomy, typed thunks, store registration, persistence consequences, navigation wiring. |
| `write-tests` | Jest unit tests the house way — detects the repo's unit config, the `.test.ts`-only `testMatch` trap, fixture-builder style. |
| `validate-change` | Which checks match which change scope, how to baseline pre-existing failures, and the handoff report format. |
| `verify` | Build, launch and drive the app on the iOS simulator with `idb` — and why synthetic clicks waste your afternoon. |
| `unistyles` | `react-native-unistyles` guide, with the full v3 docs vendored offline in `references/`. |
| `truesheet-usage` | Consumer guide for `@lodev09/react-native-true-sheet` bottom sheets. |

**Native**

| Skill | What it does |
| ----- | ------------ |
| `ios-widget` | WidgetKit extensions: the App Group snapshot architecture, scripting the extension target into `project.pbxproj`, the Swift bridge, offscreen Skia rendering, dark mode, and the build-verification traps. Carries a parameterized `add-widget-target.rb`. |
| `bootsplash` | Launch screen across all three surfaces (iOS storyboard, Android night resources, JS overlay), including dark variants without `react-native-bootsplash`'s paid license key. Carries the `bootsplash-dark.mjs` that generates them. |

**Workflow**

| Skill | What it does |
| ----- | ------------ |
| `gitmoji` | Gitmoji commit format, with the canonical emoji list in `references/gitmoji.json`. |
| `commit-changes` | Splits a messy working tree into small, meaningful commits — grouping by concern, hunk-level staging without interactive `git add -p`, and what never gets swept in. |
| `ticket-shaping` | Turns a fuzzy UX-level idea into an implementation-ready ticket, via a one-question-at-a-time interview plus a plan you argue with. Writes to whichever tracker the repo configured. |
| `implement-ticket` | Implements a ticket end-to-end: fetch, grill the plan, implement, test, mark In Review. Tracker (Linear, Notion, or in-repo `docs/tickets/`) is picked once per repo and stored in `.claude/ticket-tracker.json`. |
| `maintain-skills` | Keeps this library and per-project `.claude/skills/` correct — drift checks, the promotion test for moving a project skill into this plugin, description quality bar. |

Deliberately **not** here: skills that only make sense in one repo (a codebase
orientation map, a sync/merge guardrail, an IAP guardrail). Those stay in that
project's `.claude/skills/`. `maintain-skills` describes the promotion test for
deciding which is which.

- **Marketplace** = the catalog (this repo). It *indexes* plugins; it doesn't have to host them.
- **Plugin** = an installable bundle of one or more skills (and optionally agents, hooks, MCP servers).
- **Skill** = a single `SKILL.md` (folder name is the skill name).

### Names

Three independent names are in play — none has to match the others:

| Name           | Set in                          | Where you see it              |
| -------------- | ------------------------------- | ----------------------------- |
| `skills`       | the repo/folder name            | the git URL only              |
| `adora-skills` | `marketplace.json` → `name`     | the `@` half of an install    |
| `adora`        | `plugin.json` → `name`          | the plugin half, and `/adora:` |

Together they make `/plugin install adora@adora-skills`, and skills resolve as
`/adora:build-ui`. Renaming the repo changes nothing; renaming the **marketplace**
after publishing breaks existing installs, since `@adora-skills` is what users record
in their settings.

The plugin's `source` is `"./"`, so the repo root doubles as the plugin root. Keeping
`skills/` at the top level is what lets a single copy of each skill serve **both**
install paths below. Nesting them under `plugins/<name>/skills/` would still work for
the plugin, but hides them from the skills.sh installer.

## First-time setup

```bash
git init && git add . && git commit -m "Initial marketplace"
# create an empty repo on GitHub first, then:
git remote add origin git@github.com:<you>/skills.git
git push -u origin main
```

Validate before pushing:

```bash
claude plugin validate .
```

## Installing

Two ways, with different trade-offs.

### 1. As a Claude Code plugin — the whole bundle

```bash
# register the marketplace once (name comes from marketplace.json -> "adora-skills")
/plugin marketplace add <you>/skills

# install the plugin
/plugin install adora@adora-skills
```

Installs **all** skills as one managed, read-only bundle that updates when you push.
The plugin is the unit of installation — there is no per-skill picker at install time,
and `skillOverrides` in settings does not apply to plugin skills. Manage them with
`/plugin` (enable / disable / uninstall the plugin as a whole).

To make a skill manual-only so Claude never auto-triggers it, add
`disable-model-invocation: true` to its frontmatter. It stays callable as
`/adora:<skill-name>` but its description is kept out of context.

### 2. Via skills.sh — pick individual skills

```bash
npx skills@latest add <you>/skills
```

Prompts you to select which skills to install, then **copies** those `SKILL.md` files
into the target project so you can edit them locally. This is a third-party installer
(not Claude Code), and it also targets other Agent-Skills-standard harnesses.

Copies are forks: they stop tracking this repo, so later fixes here won't reach them.
Use the plugin when you want to subscribe; use skills.sh when you want to pick and hack.

Pick a **scope** when installing:

- **User scope** — available across all your projects (installs under `~/.claude/`). Best for general-purpose skills.
- **Project scope** — recorded in the repo's `.claude/settings.json` and shared with the team via git. Best for project-specific skills.

To make a project auto-prompt teammates to install it, add to that project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "adora-skills": { "source": { "source": "github", "repo": "<you>/skills" } }
  },
  "enabledPlugins": { "adora@adora-skills": true }
}
```

## Updating

Push changes, then on any machine:

```bash
/plugin marketplace update adora-skills
```

Bump `version` in `plugin.json` on each release, **or** omit `version` entirely so
every commit counts as a new version.

## Adding a new skill

1. Create `skills/<skill-name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: my-skill
   description: One clear sentence — what it does AND when Claude should use it.
   ---

   Instructions go here.
   ```

2. Commit, push, and run `/plugin marketplace update adora-skills`.

This repo is deliberately a **single** plugin rooted at `./`. If you later want two
plugins installable independently, that root-as-plugin layout can't express it — move
each plugin into `plugins/<name>/` with its own `.claude-plugin/plugin.json`, and point
each `marketplace.json` entry at its folder. Note that doing so takes the skills out of
skills.sh's reach, trading per-skill selection for per-plugin selection.

## The mattpocock dependency

`adora` declares a real dependency on [`mattpocock/skills`](https://github.com/mattpocock/skills),
so installing `adora` also installs and enables `mattpocock-skills`:

```json
// marketplace.json
"allowCrossMarketplaceDependenciesOn": ["mattpocock"],
"plugins": [{ "dependencies": ["mattpocock-skills@mattpocock"] }]
```

The `allowCrossMarketplaceDependenciesOn` allowlist is required because his
plugin lives in a different marketplace (`mattpocock`, not `adora-skills`).
The version constraint is `*` — you track his latest on each
`/plugin marketplace update`. To review before adopting, pin a version range or
a `sha` on a re-listed entry instead (see below).

**This is why `grilling`, `grill-me`, `grill-with-docs`, and `domain-modeling`
are not in this repo** — they come from him. Vendoring copies would put two
descriptions in front of the model competing for the same trigger. Several
skills here call into his by name (`ticket-shaping` and `implement-ticket` both
invoke `grill-with-docs`).

His plugin also ships `code-review`, `diagnosing-bugs`, `tdd`, `wayfinder`,
`implement`, `to-spec`, and `to-tickets` — generic counterparts to some of the
React Native-specific skills here. Where they overlap, his is the
language-agnostic version and this one encodes the house conventions.

## Using other people's skills

Your marketplace only indexes plugins, so a plugin can live in someone else's repo.
Two approaches:

### 1. Re-list an external plugin in your catalog

Add an entry to `plugins` in `marketplace.json` whose `source` points elsewhere.
**Pin a `sha`** so you get an exact, reviewed commit rather than whatever is latest:

```json
{
  "name": "their-plugin",
  "source": {
    "source": "github",
    "repo": "someone/their-repo",
    "sha": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
  },
  "description": "Third-party skill I depend on"
}
```

Other source types: `url` (any git host), `git-subdir` (a folder inside a monorepo),
and `npm` (a published package).

### 2. Declare a real dependency (Claude Code v2.1.110+)

A plugin can depend on other plugins via its `plugin.json`/marketplace entry;
enabling it also enables its dependencies. `dependencies` is an **array of
`plugin@marketplace` strings**. To depend on a plugin from a **different**
marketplace, allowlist that marketplace by **name** at the top of
`marketplace.json` — an array of strings, not source objects:

```json
{
  "allowCrossMarketplaceDependenciesOn": ["their-marketplace"],
  "plugins": [
    {
      "name": "mine",
      "source": "./",
      "dependencies": ["their-plugin@their-marketplace"]
    }
  ]
}
```

Run `claude plugin validate .` after editing either manifest — it catches these
shapes immediately.

> ⚠️ Security: there have been demonstrated supply-chain attacks where a skill from
> an untrusted marketplace silently redirects dependency installs. Only pull from
> sources you trust. `adora` tracks `mattpocock-skills` at `*` (latest) — a
> deliberate trade of review-before-adopt for staying current. Pin a `sha` on a
> re-listed entry if you'd rather review each update.

## Docs

- Create & distribute a marketplace: https://code.claude.com/docs/en/plugin-marketplaces
- Plugin dependencies: https://code.claude.com/docs/en/plugin-dependencies
- Discover & install plugins: https://code.claude.com/docs/en/discover-plugins
