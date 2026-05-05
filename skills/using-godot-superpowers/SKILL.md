---
name: using-godot-superpowers
description: "Auto-loaded dispatcher for godot-superpowers. Establishes the design-before-code rule: any creative game-development task (new project, new feature, new mechanic, new scene, new component, new genre pack, new shader, new audio system) MUST start with the game-brainstorming skill, which produces an approved GDD and plan before any implementation skill runs."
paths: ["**/*.gd", "**/*.tscn", "**/*.tres", "**/*.gdshader", "project.godot", "**/*-gdd.md", "**/*-plan.md"]
---

# Using godot-superpowers

This file loads automatically whenever Claude touches a Godot project (matched via `paths` above). Read it first.

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (Full rationale and version-detection workflow in the "The other rule" section below.)

## Agent picker (decision table)

Use this table FIRST. It maps situation → exact `Agent` tool call. Always invoke via `Agent` with `subagent_type: "<name>"`.

| Situation | Agent | Why this one |
|---|---|---|
| Just wrote / edited a `.gd` `.tscn` `.tres` `.gdshader` | `file-verifier` | Mandatory after every write — Haiku, isolated, returns findings only |
| Implementing milestone with 3+ files or 2+ subsystems | `orchestrator` | Decomposes, dispatches workers + verifier in parallel, keeps main context flat |
| Designing scene tree / collision layout / node hierarchy | `scene-architect` | `.tscn` structure + layer math without writing scripts |
| Reviewing GDScript for quality / API drift / conventions | `code-reviewer` | Sonnet review against Godot 4.x best practices |
| Writing GUT / GdUnit4 tests, pre-release checklist | `qa-tester` | Test scaffolding + coverage gaps |
| Designing mechanics, balancing, level pacing | `game-designer` | GDD-side reasoning, not code |
| Audio pipeline, bus layout, AudioManager pattern | `sound-designer` | Pairs with `sfx-generator` skill |
| Asset generation, art bible, palette/style guide | `art-director` | Generates sprites / textures / 3D models via PixelLab / ComfyUI MCP when available; falls back to placeholders + free CC0 sources otherwise |
| Slow frame, profiler spike, GC churn investigation | `performance-profiler` | Root-cause analysis, not blanket optimization |
| Configuring export presets / signing / CI build matrix | `export-engineer` | Haiku, mechanical export config |
| "Which addon should I use for X?" / installing addons | `addon-curator` | Haiku, recommendations only |
| Project still on Godot 3.x — port to 4.x | `gdscript-migrator` | `yield`/`KinematicBody*`/`onready var` rewrites |
| Bug report from playtester → reproduce + fix + regression test | `playtest-analyst` | Triage + fix path |
| Codebase research ("where is X?", "find all callers") | `Explore` (built-in) | Read-only, isolated, cheap |
| One-shot single-file edit, known fix | direct skill / direct edit | Don't dispatch — overhead > value |

### Decision rules in priority order

1. **Did I just write a Godot source file?** → `file-verifier` first, no exceptions.
2. **Am I about to touch 3+ files for one milestone?** → `orchestrator`, never DIY.
3. **Is the question read-only?** → `Explore` or relevant analyst agent (`code-reviewer`, `performance-profiler`, `playtest-analyst`).
4. **Is the task genre-specific implementation?** → invoke the matching `genre-pack-*` SKILL directly (in main context or via worker), not an agent.
5. **None of the above** → main context, no dispatch.

### How to call

```
Agent(
  subagent_type: "<name from table>",
  description: "<3-5 word task>",
  prompt: "<self-contained brief — agent has no prior context>"
)
```

Parallelize independent dispatches in a single message (multiple `Agent` calls in one tool block) — sequential when one's output feeds the next.

## The other rule (applies always, even when the design gate is cleared)

> **Verify every API against `godot-docs` MCP before emitting code.** No exceptions.

The `godot-docs` MCP server is the only authoritative source for class names, method signatures, signal payloads, default values, and Godot 4.x feature availability. Pre-trained model knowledge of Godot drifts version by version: methods are renamed (`instance()` → `instantiate()`), arguments change (`ResourceSaver.save` flipped its args), nodes are deprecated (`TileMap` → `TileMapLayer` 4.3+), and signal signatures change.

For any code you are about to emit, especially when called from another skill:

1. Query `godot-docs` MCP for the class / method / signal you intend to use.
2. Match the user's installed Godot version (read `config/features` in `project.godot`, or fall back to `godot --version`).
3. Quote the method signature back in the response or as a comment so the user can verify.
4. If `godot-docs` MCP is unavailable in this session, say so explicitly and link to the equivalent stable URL on `https://docs.godotengine.org/en/stable/`. Do not silently fall back to memory.

When `context7` is available it is a useful secondary source for ecosystem libraries (gdtoolkit, GUT, GdUnit4, Phantom Camera, Dialogic, Beehave, LimboAI), but `godot-docs` MCP wins for engine APIs.

## The verification rule (after every write to a Godot source file)

> **After any `Edit` / `Write` to `.gd`, `.tscn`, `.tres`, or `.gdshader`, dispatch the `file-verifier` agent on that exact path before considering the change done.** Do not re-read the file in main context — the verifier reads it fresh and returns findings only.

This applies whether or not subagent dev mode is active. The verifier is cheap (Haiku), isolated (does not pollute main context), and catches the things `gdformat` / `gdlint` / `--check-only` cannot: API drift, plan deviations, composition violations, deprecated nodes for the project's Godot version.

When implementing a milestone touching 3+ files or 2+ subsystems, escalate to full subagent dev mode: hand off to the `orchestrator` agent and let it dispatch workers + verifier in parallel. See the `subagent-dev-mode` skill for the full workflow.

If a `PostToolUse` hook printed `verifier: dispatch file-verifier on <N> file(s) [...]` and you have not yet dispatched `file-verifier` for those paths, do so now.

## The design rule

> Design before code. Always. For every project, regardless of size.

If the user asks you to **start something creative** in a Godot project — new project, new mechanic, new feature, new scene, new component, new shader, new audio system, new genre pack — you MUST invoke the `game-brainstorming` skill BEFORE any of:

- `bootstrap-godot-project`
- `create-scene`, `create-component`, `create-state-machine`, `create-resource`, `create-autoload`
- `setup-collision-layers`, `setup-input-map`, `setup-save-system`, `setup-localization`
- `genre-pack-platformer`, `genre-pack-topdown`, `genre-pack-3d-action`, `genre-pack-turnbased`
- `shader-writer`, `sfx-generator`, `export-config`

`game-brainstorming` produces an approved GDD; `writing-game-plan` produces an approved plan. Both gates must clear before implementation.

## When the rule applies

Invoke `game-brainstorming` when the user says (or implies) anything in this column:

| Trigger phrase | Why it counts |
|---|---|
| "Let's start a new game" / "Let's build X" | New project — needs full GDD + plan |
| "Add a [combat / inventory / dialogue / save] system" | New subsystem — needs design pass even on existing project |
| "Make the player do Y" | New mechanic — design before scaffolding |
| "I want a level / boss / cutscene" | New content type — design pass |
| "Build a [platformer / RPG / shooter / …]" | Genre choice + scope unclear — full brainstorm |
| "Convert this from 2D to 3D" / "Refactor X" | Major change — re-brainstorm |

## When the rule does NOT apply

Skip brainstorming for:

- **Read-only investigations**: explaining code, answering "where is X", auditing, profiling. Use `godot-patterns`, `performance-audit`, `code-reviewer`, `playtest-analyst` directly.
- **Maintenance**: bug fixes with a clear repro, formatting, lint clean-up, dependency updates, doc sync (`update-docs`), migration (`gdscript-migrator`).
- **Tests for existing behavior**: `gut-test-writer` against code that already exists.
- **A user who has already approved a GDD + plan in this session** and is now executing milestones from it. The gates already cleared.

If unsure, ask the user one short question: "Is this a fix to existing behavior, or new design work?" Their answer routes you.

## Red flags — STOP and brainstorm

These thoughts mean you are about to skip the gate. Stop.

| Thought | Reality |
|---|---|
| "It's just a small feature" | Small features compound into design debt. Five minutes of brainstorming saves an hour of rework. |
| "The user clearly wants X, let me just build it" | "Clearly" usually means "I'm projecting." Ask one question. |
| "It's a prototype, design doesn't matter" | Especially for prototypes. Throwaway code only stays throwaway if you scoped it to be. |
| "I can scaffold the project and brainstorm in parallel" | No. Scaffolding decisions (renderer, autoloads, layers) depend on the GDD. |
| "The user said 'just build a platformer'" | Genre is one input. Pillars, scope, target, art direction are not. Brainstorm. |

## Order of operations for a new request

1. Read this skill (you're here).
2. Decide: design work or maintenance? (See "When the rule does/doesn't apply".)
3. If design: invoke `game-brainstorming`. Wait for GDD approval.
4. After GDD: invoke `writing-game-plan`. Wait for plan approval.
5. Only now: invoke implementation skills, milestone by milestone, per the plan.
6. After each milestone: update plan `Status`. Run `gut-test-writer`. Confirm with user before next milestone.

## Interaction with `paths` auto-loading

This skill is loaded by Claude Code whenever the conversation touches a `.gd`, `.tscn`, `.tres`, `.gdshader`, `project.godot`, or a GDD/plan markdown file. That covers every realistic Godot session. The `godot-patterns` skill is also `paths`-loaded — both apply, no conflict.
