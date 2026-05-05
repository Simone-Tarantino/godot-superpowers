# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

**godot-superpowers** — a Claude Code plugin (and drop-in `.claude/` config) that gives Claude full-spectrum Godot 4.x game-development capability across any genre. It contains skills, subagents, hooks, and MCP defaults — no game code lives here.

Targets **Godot 4.3+**. All technical content tracks the official [Godot docs](https://docs.godotengine.org/en/stable/) and [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

## Layout

```
.
├── .claude-plugin/plugin.json    # plugin manifest — declares ONLY `skills` + `mcpServers`. `agents/` and `hooks/hooks.json` are picked up by Claude Code's plugin-mode convention, not by explicit fields here.
├── .claude-plugin/marketplace.json # marketplace listing (single-plugin marketplace) — version must stay in lock-step with plugin.json
├── agents/                       # 13 subagents (auto-discovered when plugin-loaded)
├── skills/                       # 26 skills (each <name>/SKILL.md) — declared via `skills` in plugin.json
├── hooks/hooks.json              # plugin-mode hooks file (mirror of `settings.json`'s `hooks` block); not referenced by plugin.json — Claude Code reads it by convention when the plugin is loaded
├── .mcp.json                     # recommended MCP servers — declared via `mcpServers` in plugin.json. Strict to the MCP schema: no `_tier` / `_purpose` annotations inline.
├── .claude-plugin/mcp-meta.json   # human-readable tier + purpose per MCP server (sidecar — keeps `.mcp.json` strict-schema-clean)
├── settings.json                 # drop-in mode source of truth: default permissions + hooks. The `hooks` block here is canonical and is mirrored to `hooks/hooks.json` by `scripts/sync-hooks.sh`.
├── settings.local.json           # MCP enables (gitignored on real projects); see `settings.local.json.example` for the template
├── scripts/                      # repo tooling: sync-hooks.sh, validate.sh
├── LICENSE                       # MIT
├── README.md                     # plugin overview for end users
└── CLAUDE.md                     # this file
```

## Editing rules for this repo

When editing skills or agents in this directory:

- **Skill bodies are end-user docs.** Be concrete: full code blocks, exact file paths, no abstract handwaving.
- **Cite the official Godot doc URL** when explaining a non-obvious technical claim.
- **Every skill that emits code must remind the user / Claude to verify the API via the `godot-docs` MCP before shipping the snippet.** Use the standard "Authoritative source" callout (one short blockquote near the top of the skill body) so the rule is visible inline, not buried in a footnote. The dispatcher (`using-godot-superpowers`) restates the same rule globally — keep them consistent.
- **Frontmatter `description` is the discovery hook** — first sentence must contain the keywords a user would naturally use ("scaffold a player scene", "fix Godot 3 to 4 syntax", "configure collision layers").
- **Keep skills self-contained.** Cross-references between skills are fine, but a skill should be useful read in isolation.
- **English only.** Italian / other languages live in language packs (separate plugins).
- **No project-specific content.** No card-game shortcuts, no genre assumptions baked into core skills (genre packs are explicit opt-in).

## Developing this plugin

This repo IS the plugin — no separate `dist/` step. Two source-of-truth conventions matter:

1. **Hooks**: `settings.json` `.hooks` is canonical (used in drop-in mode). `hooks/hooks.json` is a mirror Claude Code reads in plugin mode (`--plugin-dir` / marketplace) by convention — `plugin.json` does NOT declare it explicitly. Whenever the `hooks` block in `settings.json` changes, run `scripts/sync-hooks.sh` to regenerate `hooks/hooks.json`. The validator below catches drift.
2. **Versions**: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` MUST share the same `version`. The validator enforces lock-step.
3. **Skill / agent frontmatter**: every skill must have `name` + `description`; every agent must have `name`. The validator enforces this.

### Local test loop

```bash
# 1. Validate the plugin self-consistency
scripts/validate.sh

# 2. Try the plugin against a real (or scratch) Godot project
claude --plugin-dir /Users/you/Code/claude-gamedev /path/to/godot/project

# 3. Or drop it in directly:
cp -R agents skills hooks settings.json .mcp.json /path/to/godot/project/.claude/
cp settings.local.json.example /path/to/godot/project/.claude/settings.local.json
# settings.local.json is gitignored in this repo — copy from the tracked .example template
```

### Pre-commit / pre-publish checklist

- `scripts/validate.sh` returns PASS
- All JSON parses (`jq empty <file>`)
- New skill added → README catalog + CLAUDE.md catalog updated, both skill counts updated
- New skill cross-references existing skill → use `[`name`](../<dir>/SKILL.md)`, validator confirms link resolves

## Hooks (active in this repo + delivered to consumers)

| Hook | Trigger | Action |
|------|---------|--------|
| `PostToolUse Edit\|Write` | Any `.gd` file written | `gdformat` runs |
| `PostToolUse Edit\|Write` | Any `.tscn` file written | `godot --headless --check-only --path "$CLAUDE_PROJECT_DIR" <file>` validates (only the first 5 lines of output are surfaced) |
| `PostToolUse Edit\|Write` | Any `.gd` / `.tscn` / `.tres` / `.gdshader` written (skipped inside subagents) | Prints `verifier: dispatch file-verifier on <N> file(s) [<paths>]` |
| `Stop` | Claude finishes response | `gdlint` on `scripts/` and `autoload/` |
| `PreToolUse Bash` | Any bash command | Blocks destructive patterns |
| `SessionStart` | Session begins | Prints Godot version + warns if `gdtoolkit` missing |

Do not bypass these hooks (no `--no-verify`, no skipping format) without user request.

## Skill catalog (26)

**Design gates** (auto-loaded; precede everything else):
- `using-godot-superpowers` — auto-loaded dispatcher (`paths: ["**/*.gd", ...]`); enforces design-before-code + verifier-after-write rule
- `game-brainstorming` — idea → approved GDD via structured Q&A; hard-gates implementation skills
- `writing-game-plan` — approved GDD → approved milestone plan; hard-gates implementation skills
- `subagent-dev-mode` — orchestrator + worker + verifier loop for milestones (3+ files / 2+ subsystems); keeps main-context tokens flat

**Foundation** (run early in a project's life, AFTER plan approved):
- `bootstrap-godot-project` — full directory + autoload scaffold
- `godot-patterns` — Godot 4.x reference (auto-loads on `.gd`/`.tscn`)
- `setup-collision-layers` — 11-layer scheme for 2D + 3D physics
- `setup-input-map` — standard actions + remap UI
- `setup-save-system` — Resource-based save/load
- `setup-localization` — CSV / gettext i18n, language switcher, font fallback

**Scaffolding** (one-off generation):
- `create-scene` — scene templates: player / enemy / level / menu / HUD / inventory / dialogue
- `create-component` — HealthComponent, Hurtbox, Hitbox, MoveComponent, Inventory, Interactable
- `create-state-machine` — node-based FSM
- `create-resource` — custom Resource classes (Item, Ability, EnemyStats, DialogueLine, ...)
- `create-autoload` — single autoload + project.godot registration

**Quality**:
- `gut-test-writer` — GUT tests with proper setup/teardown
- `performance-audit` — static scan for perf antipatterns
- `update-docs` — sync README / GDD / PROGRESS / CLAUDE

**Content**:
- `shader-writer` — 2D + 3D shader recipes
- `sfx-generator` — audio + Godot bus layout + AudioManager pattern
- `gdd-writer` — generic Game Design Document maintainer

**Build**:
- `export-config` — export presets, signing, CI builds for Win/Mac/Linux/Web/Android/iOS

**Genre packs** (opt-in, genre-specific):
- `genre-pack-platformer` — coyote time, jump buffer, variable jump, wall jump, dash
- `genre-pack-topdown` — 8-dir movement, A* pathfinding, twin-stick aim
- `genre-pack-3d-action` — SpringArm camera, lock-on, dodge roll, animation tree
- `genre-pack-turnbased` — TurnManager, Action queue, deterministic RNG

## Agent catalog (13)

| Agent | Model | Use |
|-------|-------|-----|
| `orchestrator` | sonnet | Decompose milestone → parallel workers + verifier; never writes code itself |
| `file-verifier` | haiku | External semantic check on a single Godot file after every Edit/Write; findings only |
| `code-reviewer` | sonnet | GDScript review against Godot 4.x best practices |
| `scene-architect` | sonnet | `.tscn` hierarchies + collision layers |
| `game-designer` | sonnet | Mechanics, balancing, level design |
| `qa-tester` | sonnet | GUT/GdUnit4 tests, pre-release checklists |
| `sound-designer` | sonnet | Audio pipeline, AudioManager |
| `art-director` | sonnet | Asset generation, art bible |
| `performance-profiler` | sonnet | Bottleneck investigation |
| `export-engineer` | haiku | Export presets, signing, CI |
| `addon-curator` | haiku | Addon recommendations + install |
| `gdscript-migrator` | sonnet | Godot 3.x → 4.x code migration |
| `playtest-analyst` | sonnet | Bug reports → fixes + regression tests |

## Agent picker (situation → call)

Always invoke via `Agent` tool with `subagent_type: "<name>"`. Full table also in `using-godot-superpowers` skill (auto-loaded on `.gd`/`.tscn`).

| Situation | Call |
|---|---|
| Just wrote `.gd` / `.tscn` / `.tres` / `.gdshader` | `file-verifier` (mandatory) |
| Milestone with 3+ files or 2+ subsystems | `orchestrator` |
| Scene tree / collision layout design | `scene-architect` |
| GDScript review / API drift check | `code-reviewer` |
| GUT / GdUnit4 tests, pre-release QA | `qa-tester` |
| Mechanic / balancing / level pacing design | `game-designer` |
| Audio bus + AudioManager planning | `sound-designer` |
| Art bible / asset plan / palette | `art-director` |
| Frame spike / profiler / GC investigation | `performance-profiler` |
| Export presets / signing / CI | `export-engineer` |
| Addon recommendation / install | `addon-curator` |
| Godot 3.x → 4.x port | `gdscript-migrator` |
| Playtester bug → fix + regression test | `playtest-analyst` |
| Codebase research / "where is X?" | `Explore` (built-in) |
| Single-file edit, known fix | direct skill, no dispatch |

Priority: (1) verifier after any write — no exceptions; (2) orchestrator on multi-file milestone; (3) read-only → analyst agent; (4) genre-pack → skill directly. Otherwise main context.

## Project-side rules these skills/agents enforce

When operating in a downstream Godot project, the skills and agents enforce:

- **Composition > inheritance** — components as child nodes, not deep `extends` chains
- **Type hints everywhere** — `var x: int`, `func f(a: int) -> void`
- **Signals connected in code** in `_ready()`, never in editor
- **`@onready` for repeated lookups** — never `$Path` in `_process` / `_physics_process`
- **Custom Resources for game data** — never Dictionary literals
- **Unique scene names (`%`)** instead of long `$Path/To/Node`
- **`change_scene_to_packed()`** with preloaded `PackedScene`
- **`TileMapLayer`** (4.3+) over deprecated `TileMap`
- **`Parallax2D`** (4.3+) over deprecated `ParallaxBackground` / `ParallaxLayer`
- **Hurtbox/Hitbox on separate collision layers** per `setup-collision-layers`
- **Resource save** for game state (not JSON; JSON loses Vector2/Color/typed objects)
- **`_unhandled_input`** for action triggers, not `_input` (UI takes precedence)

## Distribution

This plugin can be:

1. **Installed via Claude Code marketplace** (once published) — namespaced as `/godot-superpowers:<skill>`
2. **Loaded locally** — `claude --plugin-dir /path/to/godot-superpowers`
3. **Copied as `.claude/`** — drop `agents/`, `skills/`, `hooks/`, `settings.json`, `.mcp.json` into a project's `.claude/` directory, plus `settings.local.json.example` copied as `.claude/settings.local.json` (the source file is gitignored here, so the tracked `.example` is the install template). The template uses an explicit `enabledMcpjsonServers` whitelist (tier 1 only by default); tier 2 servers (`git`, `memory`) are opt-in. Without `settings.local.json`, `.mcp.json` is declarative-only and no server starts. Keep `settings.local.json` gitignored on real projects (per-user state).

When copied as `.claude/` (option 3), skills are NOT namespaced — invoked as `/<skill>` directly.

## When the user asks to add a new skill or agent

1. **Check if existing one covers it.** Many requests overlap with existing skills (especially `godot-patterns`, `create-component`, genre packs).
2. **Decide skill vs agent**: skills load inline knowledge; agents run as side tasks with isolated context.
3. **Write to the conventions above** — frontmatter, language, citations.
4. **Keep skills genre-agnostic.** Genre-specific content goes in `genre-pack-*` skills, never in foundational ones.

## Requirements (for downstream projects)

- Godot **4.3+**
- [`gdtoolkit`](https://github.com/Scony/godot-gdscript-toolkit) 4.x (`pipx install gdtoolkit==4.*`)
- Optionally GUT or GdUnit4 (per `addon-curator` recommendation)
