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

### As project config (drop-in)

Copy `agents/`, `skills/`, `hooks/`, `settings.json`, `.mcp.json`, and `settings.local.json` into your project's `.claude/` directory.

`settings.local.json` is what enables the MCP servers declared in `.mcp.json`. Without it, MCP servers won't auto-start. It is normally gitignored on real projects (per-user state), so commit `.mcp.json` but keep `settings.local.json` local.

## What you get

### 22 skills

| Category | Skill | Purpose |
|----------|-------|---------|
| **Foundation** | `bootstrap-godot-project` | Scaffold full directory layout + base autoloads |
|  | `godot-patterns` | Godot 4.x reference (auto-loaded on `.gd`/`.tscn`) |
|  | `setup-collision-layers` | Configure 2D/3D physics layer names |
|  | `setup-input-map` | Standard actions + remap UI |
|  | `setup-save-system` | Resource-based save/load |
|  | `setup-localization` | CSV / gettext i18n, language switcher, font fallback |
| **Scaffolding** | `create-scene` | Scene templates: player, enemy, level, menu, HUD |
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
| **Genre packs** | `genre-pack-platformer` | Coyote time, jump buffer, variable jump |
|  | `genre-pack-topdown` | 8-dir movement, A* pathfinding |
|  | `genre-pack-3d-action` | SpringArm camera, lock-on |
|  | `genre-pack-turnbased` | TurnManager, action queue |

### 11 subagents

| Agent | Model | Use |
|-------|-------|-----|
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
- **PostToolUse** Edit/Write `.tscn` → `godot --check-only` validation
- **Stop** → `gdlint` on `scripts/` and `autoload/`
- **PreToolUse** Bash → block destructive patterns
- **SessionStart** → Godot version check + gdtoolkit availability

### MCP servers (recommended)

| Server | Tier | Purpose |
|--------|------|---------|
| `godot-mcp` | essential | Editor automation |
| `godot-docs` | essential | Inline doc lookup |
| `context7` | essential | Library docs |
| `git`, `memory` | tier 2 | Version control + persistent memory |
| `elevenlabs` | tier 2 | Audio generation (used by `sound-designer`, `sfx-generator`) |
| `pixellab`, `comfyui` | tier 2 | Image generation (used by `art-director`) |

## Conventions enforced

- **Composition > inheritance** — components as child nodes
- **Type hints everywhere** — `var x: int`, `func f(a: int) -> void`
- **Signals connected in code** (in `_ready()`), not in editor
- **`@onready` for repeated lookups**, never `$Path` in `_process`
- **Custom Resources for game data**, not Dictionary literals
- **Unique scene names** (`%NodeName`) instead of long `$Path/To/Node`
- **TileMapLayer** (4.3+), not legacy `TileMap`
- **`change_scene_to_packed()`** with preloaded `PackedScene`
- **Hurtbox/Hitbox on separate collision layers** — see `setup-collision-layers`

## Requirements

- Godot **4.3+**
- [`gdtoolkit`](https://github.com/Scony/godot-gdscript-toolkit) 4.x — `pipx install gdtoolkit==4.*`
- Claude Code 1.x or compatible

## License

MIT
