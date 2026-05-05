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
cp -R agents skills hooks scripts settings.json .mcp.json "$TARGET"/
cp settings.local.json.example "$TARGET"/settings.local.json
```

Note: `settings.local.json` itself is **gitignored** in this repo (per-user state). The tracked template is `settings.local.json.example` — copy it into the target as `settings.local.json` and edit if needed. The default template enables only the **tier 1 (essential)** MCP servers via an explicit `enabledMcpjsonServers` whitelist (`godot-mcp`, `godot-docs`, `context7`); tier 2 servers (`git`, `memory`) are opt-in — append them to the whitelist to enable. Tier 3 server `meshy` is bundled but requires the user to export `MESHY_API_KEY` in their shell (see "MCP servers" below for the full opt-in flow). Without a `settings.local.json`, `.mcp.json` is declarative-only and no server starts.

## What you get

### 33 skills

| Category | Skill | Purpose |
|----------|-------|---------|
| **Design gates** | `using-godot-superpowers` | Auto-loaded dispatcher: enforces design-before-code + verifier-after-write rule |
|  | `game-brainstorming` | Idea → approved GDD via structured Q&A (hard-gates implementation) |
|  | `writing-game-plan` | Approved GDD → approved milestone plan (hard-gates implementation) |
|  | `codebase-survey` | Read-only map of files / APIs / hotspots a planned feature will touch on an existing project |
|  | `feature-spec` | Approved survey → approved feature spec (design delta on top of GDD) |
|  | `feature-plan` | Approved feature spec → approved feature plan (hard-gates implementation) |
| **Execution / Orchestration** | `subagent-dev-mode` | Orchestrator + worker + verifier loop for milestones (3+ files / 2+ subsystems); flat main-context tokens |
| **Foundation** | `bootstrap-godot-project` | Scaffold full directory layout + base autoloads |
|  | `setup-git-godot` | `.gitignore` + `.gitattributes` + Git LFS for binary assets |
|  | `godot-patterns` | Godot 4.x reference (auto-loaded on `.gd`/`.tscn`) |
|  | `setup-collision-layers` | 11-layer scheme for 2D + 3D physics (player, enemies, environment, projectiles, pickups, triggers, hurtboxes, hitboxes) |
|  | `setup-input-map` | Standard actions + remap UI |
|  | `setup-save-system` | Resource-based save/load |
|  | `save-schema-migration` | Version save data + sequential migrations + fixture tests |
|  | `setup-localization` | CSV / gettext i18n, language switcher, font fallback |
|  | `ui-patterns-godot` | Theme + StyleBox, focus chain, `_unhandled_input` vs `_gui_input`, stretch/scale, accessibility floor |
|  | `networking-foundation` | High-Level Multiplayer patterns: ENet/WebSocket, MultiplayerSpawner/Synchronizer, `@rpc` + authority |
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

### 15 subagents

| Agent | Model | Use |
|-------|-------|-----|
| `orchestrator` | sonnet | Decompose milestone → parallel workers + verifier; never writes code itself |
| `file-verifier` | haiku | External semantic check on a single Godot file after every Edit/Write; findings only |
| `milestone-integrator` | sonnet | Post-batch integration gate: aggregate verifier + tests, smoke `--quit-after 1` (with `--check-only` fallback), flip plan status |
| `merge-specialist` | sonnet | Repair `.tscn` / `.tres` after bad merges or refactors (conflict markers, broken IDs, UID drift) |
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
- **PostToolUse** Edit/Write `.tscn` → `godot --headless --check-only --path "$CLAUDE_PROJECT_DIR" <file>` validation (on non-zero exit, surfaces filtered error lines — `error|corrupt|failed|missing|cannot` with context — falling back to the tail of the output)
- **PostToolUse** Edit/Write `.tscn` / `.tres` → dependency-integrity check (greps `[ext_resource ... path="res://..."]` and reports missing references; advisory)
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
| `meshy` | tier 3 (bundled, needs API key) | yes | 3D model generation (text/image-to-3D, retexture, remesh, rig, animate) — used by `art-director` for 3D-asset scaffolding |
| `elevenlabs` | tier 3 (external) | **no** | Audio generation — referenced by `sound-designer` / `sfx-generator` if installed |
| `pixellab`, `comfyui` | tier 3 (external) | **no** | Image generation — referenced by `art-director` if installed |

**Tier 3 splits into two sub-cases:**

- **Bundled, needs API key (`meshy`):** the canonical npm package (`@meshy-ai/meshy-mcp-server`) is stable, so the server stanza ships in `.mcp.json` with `MESHY_API_KEY` declared as an environment passthrough. To opt in:
  1. Get a key at https://www.meshy.ai/api.
  2. Export it before launching Claude Code: `export MESHY_API_KEY=msy_...`.
  3. Append `"meshy"` to `enabledMcpjsonServers` in `settings.local.json`.
  Without the env var the `npx` invocation still runs but the server fails fast at the first API call — so leaving it out of the whitelist is the safer default.
- **External, BYO config (`elevenlabs`, `pixellab`, `comfyui`):** packages, keys, and self-hosted backends vary per user, so the server stanza is **not** shipped in `.mcp.json`. To enable, add the stanza to your project's `.mcp.json` (or to `~/.claude.json` globally) and provide the relevant credentials. The `sound-designer` and `art-director` agents detect availability at runtime and fall back to placeholders / free CC0 sources when the MCP is absent.

#### Version pinning policy

`.mcp.json` uses **floating versions** — `npx -y <package>` and `uvx <package>` without semver pins. Each install fetches whatever the registry currently considers latest.

- **Why floating:** the plugin is redistributed across many downstream projects; hard-pinned versions age out and ship known-broken upstreams to new users. Floating tracks upstream stability.
- **Risk:** behavioral drift between installs. Two users running the same plugin version may bind to different MCP server builds depending on when they installed.
- **Mitigation:** review `.mcp.json` quarterly; if a server breaks, lock the offending package inline as `package@x.y.z` in `.mcp.json` (or your project's override) until upstream is fixed. The policy is recorded under `pinning_policy` in `.claude-plugin/mcp-meta.json` — that file is also the human-readable source of truth for per-server tier and purpose annotations (kept out of `.mcp.json` so it stays strict-MCP-schema-clean).

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

## Portability across clients

The skills and agents are written against the Claude Code tool surface (Anthropic's official CLI). The _content_ (markdown bodies, design rules, code recipes) is portable; only the tool-name vocabulary changes per host:

- **Claude Code** — uses `Agent` (with `subagent_type`) for subagent dispatch, `Bash` / `Read` / `Edit` / `Write` for shell + files. This is the reference surface every skill is written against.
- **Copilot CLI** — exposes a `skill` primitive that auto-discovers installed plugin skills (functionally equivalent to Claude Code's `Skill` tool). Other tool names approximate the Claude Code surface; consult the official Copilot CLI docs for the current tool list.
- **Cursor / Codex / other agentic IDEs** — provide their own task / agent / file-edit primitives. There is no canonical 1:1 mapping and the names drift release-to-release; consult the host's current docs and substitute the equivalent primitive when reading skill bodies.

Hooks (`hooks/hooks.json`, `settings.json`) and the MCP server wiring (`.mcp.json`) are Claude Code conventions and **do not transfer 1:1** to other clients — they may be ignored, partially honored, or need rework depending on host.

## License

MIT
