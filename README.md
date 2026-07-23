![adora — ai agent skills](./adora-cover.png)

# 💖 adora-skills

![skills](https://img.shields.io/badge/skills-14-ff69b4?style=flat-square)
![version](https://img.shields.io/badge/version-0.5.0-c084fc?style=flat-square)
![claude code](https://img.shields.io/badge/Claude%20Code-v2.1.110+-d97757?style=flat-square)
![license](https://img.shields.io/badge/license-MIT-64748b?style=flat-square)

A Claude Code plugin marketplace of reusable agent skills for React Native
work — building UI, scaffolding feature modules, writing tests, validating
changes, iOS widgets, launch screens — plus a workflow set for commits, ticket
shaping, and ticket implementation.

Skills are plain `SKILL.md` files. They follow the
[Agent Skills](https://code.claude.com/docs/en/skills) format, so they work in
Claude Code as a plugin and in other Agent-Skills-compatible harnesses via
`skills.sh`.

```bash
/plugin marketplace add mattpocock/skills
/plugin marketplace add ltatarev/skills
/plugin install adora@adora-skills
```

## 🪄 Works best with react-native-template

These skills encode the conventions of
[`ltatarev/react-native-template`](https://github.com/ltatarev/react-native-template)
— a package-by-feature starter with strict TypeScript, Redux Toolkit,
MMKV-backed persistence, Unistyles theme tokens, i18n, shared UI primitives,
and adapters around native capabilities. Paired with it, the skills need no
configuration: the module anatomy `add-feature` scaffolds, the `theme/ui` kit
`build-ui` composes from, and the Jest unit harness `write-tests` targets are
all already there.

```sh
npx @react-native-community/cli@latest init MyApp \
  --template https://github.com/ltatarev/react-native-template.git
```

The template also ships an `AGENTS.md` / `CLAUDE.md` pair documenting those
conventions, so agents get the project rules and these procedures together. If
you are not using the template, copy
[`examples/react-native-AGENTS.md`](./examples/react-native-AGENTS.md) to your
project root and edit it to match your codebase — the skills lean on a file
like it being there.

They are not exclusive to it — every skill reads the repo it runs in before
acting (see below), so they work in any React Native codebase with a similar
shape. The closer your project is to the template, the less the agent has to
infer.

## 🧭 Design principles

- 🔍 **Read the repo, don't assume it.** Every skill starts by grounding itself
  in the project it runs in — theme tokens, barrel exports, script names, Jest
  config — rather than hardcoding one codebase's paths. Conventions differ; the
  procedures don't.
- 🪤 **Encode the traps.** The value is in the failure modes: the `*.test.ts`-only
  `testMatch` that silently skips your `.test.tsx`, the `StyleSheet` import that
  breaks theming, the persisted slice that ships `file://` paths to another
  device.
- ✅ **Say what "done" means.** Each skill ends with a definition of done you can
  check, not vibes.

## 📦 Requirements

- [Claude Code](https://claude.com/claude-code) v2.1.110+ for plugin
  dependencies (earlier versions can still install the plugin, without the
  dependency resolution).
- Nothing else. The skills are markdown; the two scripted references
  (`add-widget-target.rb`, `bootsplash-dark.mjs`) are invoked only by the
  skills that carry them.

## ⚡ Install

### 🧩 As a Claude Code plugin — the whole bundle

```bash
# adora depends on mattpocock-skills (see below) — add that marketplace first
/plugin marketplace add mattpocock/skills

# register this marketplace (name comes from marketplace.json)
/plugin marketplace add ltatarev/skills

# install the plugin
/plugin install adora@adora-skills
```

Installs **all** skills as one managed, read-only bundle that updates when the
repo does. The plugin is the unit of installation — there is no per-skill
picker at install time, and `skillOverrides` in settings does not apply to
plugin skills. Manage them with `/plugin` (enable / disable / uninstall the
plugin as a whole). Skills then resolve as `/adora:<skill-name>`.

If you skip the first command you'll hit `Dependency
"mattpocock-skills@mattpocock" ... not found` — `allowCrossMarketplaceDependenciesOn`
in `marketplace.json` only permits the dependency, it doesn't register the
marketplace for you, so that step can't be automated away (see
[Relationship to mattpocock/skills](#-relationship-to-mattpocockskills)).

To make a skill manual-only so Claude never auto-triggers it, add
`disable-model-invocation: true` to its frontmatter. It stays callable as
`/adora:<skill-name>` but its description is kept out of context.

### 🎛️ Via skills.sh — pick individual skills

```bash
npx skills@latest add ltatarev/skills
```

Prompts you to select which skills to install, then **copies** those `SKILL.md`
files into the target project so you can edit them locally. This is a
third-party installer (not Claude Code), and it also targets other
Agent-Skills-standard harnesses.

Copies are forks: they stop tracking this repo, so later fixes here won't reach
them. Use the plugin when you want to subscribe; use skills.sh when you want to
pick and hack.

Pick a **scope** when installing:

- **User scope** — available across all your projects (installs under
  `~/.claude/`). Best for general-purpose skills.
- **Project scope** — recorded in the repo's `.claude/settings.json` and shared
  with the team via git. Best for project-specific skills.

To make a project auto-prompt teammates to install it, add to that project's
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "adora-skills": { "source": { "source": "github", "repo": "ltatarev/skills" } }
  },
  "enabledPlugins": { "adora@adora-skills": true }
}
```

### 🔄 Updating

```bash
/plugin marketplace update adora-skills
```

## 🗂️ The skills

**📱 React Native**

| Skill | What it does |
| ----- | ------------ |
| `build-ui` | Authoring JSX to the house standard: Unistyles v3, theme tokens, the shared `theme/ui` kit, i18n + a11y, toast, worklets. |
| `add-feature` | Scaffolding or extending a `src/modules/` module: anatomy, typed thunks, store registration, persistence consequences, navigation wiring. |
| `write-tests` | Jest unit tests the house way — detects the repo's unit config, the `.test.ts`-only `testMatch` trap, fixture-builder style. |
| `validate-change` | Which checks match which change scope, how to baseline pre-existing failures, and the handoff report format. |
| `verify` | Build, launch and drive the app on the iOS simulator with `idb` — and why synthetic clicks waste your afternoon. |
| `unistyles` | `react-native-unistyles` guide, with the full v3 docs vendored offline in `references/`. |
| `truesheet-usage` | Consumer guide for `@lodev09/react-native-true-sheet` bottom sheets. |

**🍏 Native**

| Skill | What it does |
| ----- | ------------ |
| `ios-widget` | WidgetKit extensions: the App Group snapshot architecture, scripting the extension target into `project.pbxproj`, the Swift bridge, offscreen Skia rendering, dark mode, and the build-verification traps. Carries a parameterized `add-widget-target.rb`. |
| `bootsplash` | Launch screen across all three surfaces (iOS storyboard, Android night resources, JS overlay), including dark variants without `react-native-bootsplash`'s paid license key. Carries the `bootsplash-dark.mjs` that generates them. |

**🔁 Workflow**

| Skill | What it does |
| ----- | ------------ |
| `gitmoji` | Gitmoji commit format, with the canonical emoji list in `references/gitmoji.json`. |
| `commit-changes` | Splits a messy working tree into small, meaningful commits — grouping by concern, hunk-level staging without interactive `git add -p`, and what never gets swept in. |
| `ticket-shaping` | Turns a fuzzy UX-level idea into an implementation-ready ticket, via a one-question-at-a-time interview plus a plan you argue with. Writes to whichever tracker the repo configured. |
| `implement-ticket` | Implements a ticket end-to-end: fetch, grill the plan, implement, test, mark In Review. Tracker (Linear, Notion, or in-repo `docs/tickets/`) is picked once per repo and stored in `.claude/ticket-tracker.json`. |
| `maintain-skills` | Keeps a skill library and per-project `.claude/skills/` correct — drift checks, the promotion test for moving a project skill into a plugin, description quality bar. |

The React Native skills assume a package-by-feature codebase (`src/modules/`
with barrel exports, Redux Toolkit, Unistyles, i18n) — see
[Works best with react-native-template](#-works-best-with-react-native-template).

Deliberately **not** here: skills that only make sense in a single repo (a
codebase orientation map, a sync/merge guardrail, an in-app-purchase
guardrail). Those belong in that project's `.claude/skills/`.
`maintain-skills` describes the promotion test for deciding which is which.

## 🤝 Relationship to mattpocock/skills

`adora` declares a real dependency on
[`mattpocock/skills`](https://github.com/mattpocock/skills), so installing
`adora` also installs and enables `mattpocock-skills`:

```json
// marketplace.json
"allowCrossMarketplaceDependenciesOn": ["mattpocock"],
"plugins": [{ "dependencies": ["mattpocock-skills@mattpocock"] }]
```

The `allowCrossMarketplaceDependenciesOn` allowlist is required because that
plugin lives in a different marketplace (`mattpocock`, not `adora-skills`).
The version constraint is `*` — you track its latest on each
`/plugin marketplace update`.

**This is why `grilling`, `grill-me`, `grill-with-docs`, and `domain-modeling`
are not in this repo.** Vendoring copies would put two descriptions in front of
the model competing for the same trigger. Several skills here call into those
by name (`ticket-shaping` and `implement-ticket` both invoke
`grill-with-docs`).

That plugin also ships `code-review`, `diagnosing-bugs`, `tdd`, `wayfinder`,
`implement`, `to-spec`, and `to-tickets` — generic counterparts to some of the
React Native-specific skills here. Where they overlap, those are the
language-agnostic version and these encode the house conventions.

## 🏗️ Repo layout

```text
.
├── .claude-plugin/
│   ├── marketplace.json   # the catalog: lists plugins + where to find them
│   └── plugin.json        # this repo IS the plugin (marketplace entry uses "source": "./")
└── skills/
    ├── add-feature/SKILL.md
    ├── bootsplash/         # + references/bootsplash-dark.mjs
    ├── build-ui/SKILL.md
    ├── commit-changes/SKILL.md
    ├── gitmoji/            # + references/gitmoji.json
    ├── implement-ticket/SKILL.md
    ├── ios-widget/         # + references/add-widget-target.rb
    ├── maintain-skills/SKILL.md
    ├── ticket-shaping/SKILL.md
    ├── truesheet-usage/    # + references/*.md
    ├── unistyles/          # + references/unistyles.md (full offline docs)
    ├── validate-change/SKILL.md
    ├── verify/SKILL.md
    └── write-tests/SKILL.md
```

- **Marketplace** = the catalog (this repo). It *indexes* plugins; it doesn't
  have to host them.
- **Plugin** = an installable bundle of one or more skills (and optionally
  agents, hooks, MCP servers).
- **Skill** = a single `SKILL.md` (folder name is the skill name).

The plugin's `source` is `"./"`, so the repo root doubles as the plugin root.
Keeping `skills/` at the top level is what lets a single copy of each skill
serve **both** install paths above — nesting them under
`plugins/<name>/skills/` would still work for the plugin, but hides them from
the skills.sh installer.

### 🏷️ Three names

None of them has to match the others:

| Name           | Set in                      | Where you see it               |
| -------------- | --------------------------- | ------------------------------ |
| `skills`       | the repo/folder name        | the git URL only               |
| `adora-skills` | `marketplace.json` → `name` | the `@` half of an install     |
| `adora`        | `plugin.json` → `name`      | the plugin half, and `/adora:` |

Together they make `/plugin install adora@adora-skills`. Renaming the repo
changes nothing; renaming the **marketplace** after publishing breaks existing
installs, since `@adora-skills` is what users record in their settings.

## 🙌 Contributing

Issues and pull requests are welcome — especially fixes to a skill that steered
an agent wrong in your repo, and new traps worth encoding.

Adding a skill:

1. Create `skills/<skill-name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: my-skill
   description: One clear sentence — what it does AND when Claude should use it.
   ---

   Instructions go here.
   ```

2. Run `claude plugin validate .`.
3. Bump `version` in `.claude-plugin/plugin.json` **and** the marketplace entry
   — they have to agree. The `skills` and `version` badges at the top of this
   README are static; nudge them too.

The bar for a skill: the description states both *what* and *when* (that string
is all the model sees when deciding to load it), the body grounds itself in the
target repo before acting, and it ends with a checkable definition of done.
Long reference material goes in `references/` so it loads only when needed.

Anything larger than a fix — run `maintain-skills`, which encodes the drift
checks and the quality bar this library is held to.

## 🍴 Forking this as your own marketplace

Fork, then edit the two manifests: `name`/`owner` in
`.claude-plugin/marketplace.json`, and `name` in `.claude-plugin/plugin.json`.
Both names are yours to pick; the repo name is irrelevant to the tooling.

This repo is deliberately a **single** plugin rooted at `./`. If you want two
plugins installable independently, that root-as-plugin layout can't express it
— move each plugin into `plugins/<name>/` with its own
`.claude-plugin/plugin.json`, and point each `marketplace.json` entry at its
folder. That takes the skills out of skills.sh's reach, trading per-skill
selection for per-plugin selection.

### 🔗 Indexing someone else's plugin

A marketplace only indexes plugins, so a plugin can live in someone else's
repo. Add an entry to `plugins` whose `source` points elsewhere, and **pin a
`sha`** so you get an exact, reviewed commit rather than whatever is latest:

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

Other source types: `url` (any git host), `git-subdir` (a folder inside a
monorepo), and `npm` (a published package).

Alternatively, declare a real dependency (Claude Code v2.1.110+). Enabling a
plugin also enables its dependencies. `dependencies` is an **array of
`plugin@marketplace` strings**; to depend on a plugin from a **different**
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

> ⚠️ **Security.** There have been demonstrated supply-chain attacks where a
> skill from an untrusted marketplace silently redirects dependency installs.
> Only pull from sources you trust. `adora` tracks `mattpocock-skills` at `*`
> (latest) — a deliberate trade of review-before-adopt for staying current. Pin
> a `sha` on a re-listed entry if you'd rather review each update.

## 📚 Docs

- [Create & distribute a marketplace](https://code.claude.com/docs/en/plugin-marketplaces)
- [Plugin dependencies](https://code.claude.com/docs/en/plugin-dependencies)
- [Discover & install plugins](https://code.claude.com/docs/en/discover-plugins)
- [Agent Skills format](https://code.claude.com/docs/en/skills)

## 💀 License

MIT © [ltatarev](https://github.com/ltatarev)
