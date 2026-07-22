# lu-skills

A personal Claude Code plugin marketplace — a single repo that holds reusable
skills so they can be installed across all my projects or globally.

## Structure

```
lu-skills/
├── .claude-plugin/
│   └── marketplace.json          # the catalog: lists plugins + where to find them
└── plugins/
    └── adora-skills/                 # one plugin; bundles related skills
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            ├── code-review/SKILL.md
            └── react-component/SKILL.md
```

- **Marketplace** = the catalog (this repo). It *indexes* plugins; it doesn't have to host them.
- **Plugin** = an installable bundle of one or more skills (and optionally agents, hooks, MCP servers).
- **Skill** = a single `SKILL.md` (folder name is the skill name).

## First-time setup

```bash
git init && git add . && git commit -m "Initial marketplace"
# create an empty repo on GitHub first, then:
git remote add origin git@github.com:<you>/lu-skills.git
git push -u origin main
```

Validate before pushing:

```bash
claude plugin validate .
```

## Installing

```bash
# register the marketplace once (name comes from marketplace.json -> "lu-skills")
/plugin marketplace add <you>/lu-skills

# install the plugin
/plugin install adora-skills@lu-skills
```

Pick a **scope** when installing:

- **User scope** — available across all your projects (installs under `~/.claude/`). Best for general-purpose skills.
- **Project scope** — recorded in the repo's `.claude/settings.json` and shared with the team via git. Best for project-specific skills.

To make a project auto-prompt teammates to install it, add to that project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "lu-skills": { "source": { "source": "github", "repo": "<you>/lu-skills" } }
  },
  "enabledPlugins": { "adora-skills@lu-skills": true }
}
```

## Updating

Push changes, then on any machine:

```bash
/plugin marketplace update lu-skills
```

Bump `version` in `plugin.json` on each release, **or** omit `version` entirely so
every commit counts as a new version.

## Adding a new skill

1. Create `plugins/adora-skills/skills/<skill-name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: my-skill
   description: One clear sentence — what it does AND when Claude should use it.
   ---

   Instructions go here.
   ```

2. Commit, push, and run `/plugin marketplace update lu-skills`.

Group unrelated skills into separate plugins (add more folders under `plugins/`
and more entries in `marketplace.json`) so people can install only what they need.

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
enabling it also enables its dependencies, and you can constrain versions with
semver ranges. To depend on a plugin from a **different** marketplace, allowlist
that marketplace at the top of `marketplace.json`:

```json
{
  "allowCrossMarketplaceDependenciesOn": [
    { "source": "github", "repo": "trusted-org/their-marketplace" }
  ]
}
```

> ⚠️ Security: there have been demonstrated supply-chain attacks where a skill from
> an untrusted marketplace silently redirects dependency installs. Only pull from
> sources you trust, and pin third-party plugins to a specific commit `sha`.

## Docs

- Create & distribute a marketplace: https://code.claude.com/docs/en/plugin-marketplaces
- Plugin dependencies: https://code.claude.com/docs/en/plugin-dependencies
- Discover & install plugins: https://code.claude.com/docs/en/discover-plugins
