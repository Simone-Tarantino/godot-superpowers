# godot-superpowers

Full-spectrum **Godot 4.x** game development toolkit for [Claude Code](https://claude.com/claude-code). Adds skills, subagents, hooks, and sane defaults so Claude can productively scaffold, review, test, and ship games of any genre.

Targets **Godot 4.3+** (TileMapLayer / Parallax2D era). All skills follow the official [Godot docs](https://docs.godotengine.org/en/stable/) and [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

## Install

### As a Claude Code plugin (recommended)

```bash
# from a marketplace once published, or local clone:
claude --plugin-dir /path/to/godot-superpowers
```

Skills then namespaced as `/godot-superpowers:<skill-name>`.

> The plugin manifest (`.claude-plugin/plugin.json`) explicitly declares only `skills` + `mcpServers`. Subagents under `agents/` and hooks in `hooks/hooks.json` are picked up automatically by Claude Code's plugin-mode convention — no extra wiring required.

### As project config (drop-in)

```bash
TARGET=/path/to/godot/project/.claude
mkdir -p "$TARGET"
cp -R agents skills hooks settings.json .mcp.json "$TARGET"/
cp settings.local.json.example "$TARGET"/settings.local.json
```

Note: `settings.local.json` itself is **gitignored** in this repo (per-user state). The tracked template is `settings.local.json.example` — copy it into the target as `settings.local.json` and edit if needed. The default template enables only the **tier 1 (essential)** MCP servers via an explicit `enabledMcpjsonServers` whitelist (`godot-mcp`, `godot-docs`, `context7`); tier 2 servers (`git`, `memory`) are opt-in — append them to the whitelist to enable. Without a `settings.local.json`, `.mcp.json` is declarative-only and no server starts.

## What you get

### 29 skills

| Category | Skill | Purpose |
|----------|-------|---------|
| **Design gates** | `using-godot-superpowers` | Auto-loaded dispatcher: enforces design-before-code + verifier-after-write rule |
|  | `game-brainstorming` | Idea → approved GDD via structured Q&A (hard-gates implementation) |
|  | `writing-game-plan` | Approved GDD → approved milestone plan (hard-gates implementation) |
|  | `codebase-survey` | Read-only map of files / APIs / hotspots a planned feature will touch on an existing project |
|  | `feature-spec` | Approved survey → approved feature spec (design delta on top of GDD) |
|  | `feature-plan` | Approved feature spec → approved feature plan (hard-gates implementation) |
|  | `subagent-dev-mode` | Orchestrator + worker + verifier loop for milestones (3+ files / 2+ subsystems); flat main-context tokens |
| **Foundation** | `bootstrap-godot-project` | Scaffold full directory layout + base autoloads |
|  | `godot-patterns` | Godot 4.x reference (auto-loaded on `.gd`/`.tscn`) |
|  | `setup-collision-layers` | 11-layer scheme for 2D + 3D physics (player, enemies, environment, projectiles, pickups, triggers, hurtboxes, hitboxes) |
|  | `setup-input-map` | Standard actions + remap UI |
|  | `setup-save-system` | Resource-based save/load |
|  | `setup-localization` | CSV / gettext i18n, language switcher, font fallback |
| **Scaffolding** | `create-scene` | 2D/3D scene templates: player, enemy, level, main menu, pause menu, HUD, inventory UI, dialogue UI |
|  | `create-component` | HealthComponent, Hurtbox, Hitbox, etc. |
|  | `create-state-machine` | Node-based state machine + states |
|  | `create-resource` | Custom Resource classes for game data |
|  | `create-autoload` | Add singleton + register in project.godot |
| **Quality** | `gut-test-writer` | GUT unit tests with proper teardown |
|  | `performance-audit` | Find perf antipatterns |
|  | `update-docs` | Sync README/GDD/PROGRESS/CLAUDE |
| **Content** | `shader-writer` | 2D/3D shader recipes |
|  | `sfx-generator` | Audio generation + Godot bus layout |
|  | `gdd-writer` | Generic Game Design Document |
| **Build** | `export-config` | Export presets for Win/Mac/Linux/Web/Android/iOS |
| **Genre packs** | `genre-pack-platformer` | Coyote time, jump buffer, variable jump, wall jump, dash |
|  | `genre-pack-topdown` | 8-dir movement, A* pathfinding, twin-stick aim |
|  | `genre-pack-3d-action` | SpringArm camera, lock-on, dodge roll, animation tree |
|  | `genre-pack-turnbased` | TurnManager, action queue, deterministic RNG |

### 13 subagents

| Agent | Model | Use |
|-------|-------|-----|
| `orchestrator` | sonnet | Decompose milestone → parallel workers + verifier; never writes code itself |
| `file-verifier` | haiku | External semantic check on a single Godot file after every Edit/Write; findings only |
| `code-reviewer` | sonnet | GDScript review against Godot 4.x best practices |
| `scene-architect` | sonnet | Design `.tscn` hierarchies + collision layers |
| `game-designer` | sonnet | Mechanics, balancing, level design |
| `qa-tester` | sonnet | GUT/GdUnit4 tests, pre-release checklists |
| `sound-designer` | sonnet | Audio pipeline, AudioManager |
| `art-director` | sonnet | Asset generation, art bible |
| `performance-profiler` | sonnet | Find bottlenecks, suggest MultiMesh/pooling |
| `export-engineer` | haiku | Configure export presets, signing, CI builds |
| `addon-curator` | haiku | Suggest/install addons (Dialogic, Phantom Camera, Beehave, etc.) |
| `gdscript-migrator` | sonnet | Migrate Godot 3.x code to 4.x |
| `playtest-analyst` | sonnet | Reproduce bugs, analyze playtest reports |

### Hooks

- **PostToolUse** Edit/Write `.gd` → `gdformat`
- **PostToolUse** Edit/Write `.tscn` → `godot --headless --check-only --path "$CLAUDE_PROJECT_DIR" <file>` validation (first 5 lines of output surfaced)
- **PostToolUse** Edit/Write `.gd`/`.tscn`/`.tres`/`.gdshader` → prints `verifier: dispatch file-verifier on <N> file(s) [<paths>]` (skipped inside subagents)
- **Stop** → `gdlint` on `scripts/` and `autoload/`
- **PreToolUse** Bash → block destructive patterns
- **SessionStart** → Godot version check + gdtoolkit availability

### MCP servers (recommended)

| Server | Tier | Bundled in `.mcp.json` | Purpose |
|--------|------|---|---------|
| `godot-mcp` | tier 1 (essential) | yes | Editor automation |
| `godot-docs` | tier 1 (essential) | yes | Inline doc lookup |
| `context7` | tier 1 (essential) | yes | Library docs |
| `git`, `memory` | tier 2 (recommended) | yes | Version control + persistent memory |
| `elevenlabs` | tier 3 (external) | **no** | Audio generation — referenced by `sound-designer` / `sfx-generator` if installed |
| `pixellab`, `comfyui` | tier 3 (external) | **no** | Image generation — referenced by `art-director` if installed |

**Tier 3 servers are optional external integrations.** They are NOT shipped in `.mcp.json` because their npm packages, API keys, and self-hosted backends vary per user. To enable them, add the server stanza to your project's `.mcp.json` (or to `~/.claude.json` globally) and provide the relevant credentials. The `sound-designer` and `art-director` agents detect availability at runtime and fall back to placeholders / free CC0 sources when the MCP is absent.

## Conventions enforced

- **Composition > inheritance** — components as child nodes
- **Type hints everywhere** — `var x: int`, `func f(a: int) -> void`
- **Signals connected in code** (in `_ready()`), not in editor
- **`@onready` for repeated lookups**, never `$Path` in `_process`
- **Custom Resources for game data**, not Dictionary literals
- **Unique scene names** (`%NodeName`) instead of long `$Path/To/Node`
- **TileMapLayer** (4.3+), not legacy `TileMap`
- **`Parallax2D`** (4.3+) over deprecated `ParallaxBackground` / `ParallaxLayer`
- **`change_scene_to_packed()`** with preloaded `PackedScene`
- **Hurtbox/Hitbox on separate collision layers** — see `setup-collision-layers`
- **Resource save** for game state (not JSON — JSON loses Vector2 / Color / typed objects)
- **`_unhandled_input`** for action triggers, not `_input` (UI takes precedence)

## Requirements

- Godot **4.3+**
- [`gdtoolkit`](https://github.com/Scony/godot-gdscript-toolkit) 4.x — `pipx install gdtoolkit==4.*`
- Claude Code 1.x or compatible

## License

MIT
