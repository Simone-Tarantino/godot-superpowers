---
name: using-godot-superpowers
description: "Auto-loaded dispatcher for godot-superpowers. Establishes the design-before-code rule (soft-gated — opt-out via `/skip-design`) across two trails: trail A (greenfield) routes to game-brainstorming → gdd-writer → writing-game-plan; trail B (feature on an existing game) routes to codebase-survey → feature-spec → feature-plan. Any creative game-development task (new project, new feature, new mechanic, new scene, new component, new genre pack, new shader, new audio system) should clear both gates of the matching trail before implementation, unless the user explicitly opts out."
paths: ["**/*.gd", "**/*.tscn", "**/*.tres", "**/*.gdshader", "project.godot", "**/*-gdd.md", "**/*-plan.md", "**/*-feature.md", "**/*-feature-plan.md", "**/*-survey.md"]
---

# Using godot-superpowers

This file loads automatically whenever Claude touches a Godot project (matched via `paths` above). Read it first.

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (Full rationale and version-detection workflow in the "The other rule" section below.)

## Agent picker (decision table)

Use this table FIRST. It maps situation → exact `Agent` tool call. Always invoke via `Agent` with `subagent_type: "<name>"`.

| Situation | Agent | Why this one |
|---|---|---|
| Wrote a batch of `.gd` `.tscn` `.tres` `.gdshader` (3+ files) or a single risky one | `file-verifier` | Recommended after milestone-sized batches; skip for single trivial edits — Haiku, isolated, returns findings only |
| Implementing milestone with 3+ files or 2+ subsystems | `orchestrator` | Decomposes, dispatches workers + verifier in parallel, keeps main context flat |
| Milestone batch finished — confirm integration before declaring done | `milestone-integrator` | Aggregates verifier verdicts + tests, runs `--quit-after 1` smoke on main scene (with `--check-only` fallback), flips plan status |
| `.tscn` / `.tres` corrupted by merge or refactor (broken IDs / UIDs / `<<<<<<<` markers) | `merge-specialist` | Repair scene grammar, dedupe ids, fix paths, restore UIDs from git — text repair, not redesign |
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

1. **Did I just write 3+ Godot source files in one milestone?** → dispatch `file-verifier` on the batch.
2. **Did I just touch a single risky file (deprecated API, hot path, security-relevant)?** → dispatch `file-verifier` on it. Otherwise skip — main-context Read + lint covers the trivial cases.
3. **Am I about to touch 3+ files for one milestone?** → `orchestrator`, never DIY (the orchestrator owns its own verifier dispatch).
4. **Is the question read-only?** → `Explore` or relevant analyst agent (`code-reviewer`, `performance-profiler`, `playtest-analyst`).
5. **Is the task genre-specific implementation?** → invoke the matching `genre-pack-*` SKILL directly (in main context or via worker), not an agent.
6. **None of the above** → main context, no dispatch.

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

### Which MCP for which job

The plugin exposes both `godot-mcp` and `godot-docs`. They do different things — pick the right one:

| Need | Server | Why |
|------|--------|-----|
| Class names, method signatures, signal payloads, enum values, default args, version availability of a Godot 4.x API | `godot-docs` | Authoritative engine documentation. Always preferred for code emission. |
| Run a scene headless / inspect a running project / read or edit `project.godot` and `.tscn` / list nodes / autoloads | `godot-mcp` | Editor + project automation. Use during scaffolding, debugging, or when verifying a real project's state instead of guessing. |
| Library docs (gdtoolkit, GUT, GdUnit4, Phantom Camera, Dialogic, Beehave, LimboAI, third-party addons) | `context7` | Ecosystem coverage; not engine APIs. |

If both `godot-mcp` and `godot-docs` could plausibly answer (e.g. "what does `CharacterBody2D.move_and_slide` return?"), **prefer `godot-docs`** — it is the single source of truth for engine APIs. Reach for `godot-mcp` only when you need to *act on* or *read from* the user's actual project, not the docs.

## The verification rule (after a batch of Godot writes — NOT every single file)

> **Dispatch `file-verifier` when (a) you've written 3+ Godot source files in one milestone, or (b) the single file you just wrote is risky (deprecated API surface, hot path, security-relevant, large refactor).** For trivial single-file edits, skip — `gdformat` / `gdlint` / `--check-only` already run via PostToolUse hooks, and main-context Read covers the rest. Verifier dispatch costs a sub-agent invocation; reserve it for the cases where the cost is worth it.

When the verifier IS invoked, the agent reads the file fresh and returns findings only. Do not re-read the file in main context after dispatch.

The PostToolUse hook (`verifier-reminder.sh`) accumulates write counts and prints `verifier: dispatch file-verifier on <N> file(s) [...]` only once a session reaches the threshold (default 3, override via `CLAUDE_VERIFIER_THRESHOLD` env var). When you see that line, dispatch the verifier. Below the threshold, the hook stays silent — that is expected.

When implementing a milestone touching 3+ files or 2+ subsystems, escalate to full subagent dev mode: hand off to the `orchestrator` agent and let it dispatch workers + verifier in parallel. See the `subagent-dev-mode` skill for the full workflow.

## The design rule (soft-gate)

> Design before code is the default. The user can opt out per-session with `/skip-design` (or any clear equivalent — "skip design", "no GDD", "just build it").

If the user asks you to **start something creative** in a Godot project — new project, new mechanic, new feature, new scene, new component, new shader, new audio system, new genre pack — propose the matching design trail BEFORE any of these implementation skills run:

- `bootstrap-godot-project`
- `create-scene`, `create-component`, `create-state-machine`, `create-resource`, `create-autoload`
- `setup-collision-layers`, `setup-input-map`, `setup-save-system`, `setup-localization`, `save-schema-migration`
- `ui-patterns-godot`, `networking-foundation`, `setup-git-godot`
- `genre-pack-platformer`, `genre-pack-topdown`, `genre-pack-3d-action`, `genre-pack-turnbased`
- `shader-writer`, `sfx-generator`, `export-config`

The list above is illustrative, not exhaustive. Any skill that introduces game behavior, infrastructure, or persistent project layout (autoloads, layers, schemas, network code, repo configuration) requires the gate. When in doubt, gate.

There are two trails. Pick exactly one based on whether the project already has Godot source files.

**Trail A — greenfield (no `project.godot` yet, or whole-game redesign):**

1. `game-brainstorming` → conducts the structured Q&A.
2. `gdd-writer` → produces an approved GDD at `docs/design/<YYYY-MM-DD>-<slug>-gdd.md`.
3. `writing-game-plan` → produces an approved plan at `docs/plans/<YYYY-MM-DD>-<slug>-plan.md`.

**Trail B — feature on an existing game (`project.godot` exists, change is bounded):**

1. `codebase-survey` → produces a read-only file/API/hotspot map at `docs/features/<YYYY-MM-DD>-<slug>-survey.md` (skippable for trivial one-file changes).
2. `feature-spec` → produces an approved feature spec at `docs/features/<YYYY-MM-DD>-<slug>-feature.md`.
3. `feature-plan` → produces an approved feature plan at `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md`.

> **Trivial-feature shortcut.** Step 1 (`codebase-survey`) may be skipped if and only if ALL three hold: (a) the change touches exactly one file, (b) it adds no new mechanic, (c) it adds no new public surface (no new signal, exported var, autoload, or input action). When skipped, the spec header MUST contain the canonical marker string `Survey reference: none (trivial shortcut)` exactly — `feature-plan` keys off this string. If any condition fails, the survey is mandatory. See [`codebase-survey`](../codebase-survey/SKILL.md) and [`feature-spec`](../feature-spec/SKILL.md) for the canonical rule.

Both trails end in an approved plan file. Both gates apply by default before implementation; the user may opt out per-session with `/skip-design`. When the user opts out, warn ONCE that scope creep / regression risk are the typical failure modes, get a confirmation, then proceed without further re-warning in the same session. The `orchestrator` agent applies the same soft-gate on dispatch — it refuses to run unless either the matching plan is `Status: Approved` OR the user has explicitly waived the gate for the session (record the waiver in the orchestrator's prompt).

If the change starts as trail B but turns out to touch every system, escalate to trail A and re-plan from scratch — do not silently mutate a feature plan into a whole-game plan.

## When the rule applies

Two design trails exist. Pick the trail that matches the user's situation, then route to the first skill.

### Trail A — Greenfield (no game yet, or whole-game redesign)

First skill: `game-brainstorming`.

| Trigger phrase | Why it counts |
|---|---|
| "Let's start a new game" / "Let's build X" | New project — needs full GDD + plan |
| "Build a [platformer / RPG / shooter / …]" | Genre choice + scope unclear — full brainstorm |
| "Convert this from 2D to 3D" / "Refactor whole game X" | Major redesign — re-brainstorm |

### Trail B — Feature on existing game (code already exists)

First skill: `codebase-survey`. Then `feature-spec`. Then `feature-plan`.

| Trigger phrase | Why it counts |
|---|---|
| "Add a [combat / inventory / dialogue / save] system to this game" | New subsystem on existing code — needs design pass scoped to a delta |
| "Make the player do Y" / "Add double jump / dash / wall slide" | New mechanic on existing player — survey + spec + plan |
| "I want a level / boss / cutscene in this game" | New content type — design pass scoped to a delta |
| "Tweak / extend an existing mechanic" | Bounded change — survey first, then spec |

If the change is genuinely cross-cutting (touches every system), it's a re-plan — escalate to trail A.

## When the rule does NOT apply

Skip brainstorming for:

- **Read-only investigations**: explaining code, answering "where is X", auditing, profiling. Use `godot-patterns`, `performance-audit`, `code-reviewer`, `playtest-analyst` directly.
- **Maintenance**: bug fixes with a clear repro, formatting, lint clean-up, dependency updates, doc sync (`update-docs`), migration (`gdscript-migrator`).
- **Tests for existing behavior**: `gut-test-writer` against code that already exists.
- **A user who has already approved a GDD + plan in this session** and is now executing milestones from it. The gates already cleared.

If unsure, ask the user one short question: "Is this a fix to existing behavior, or new design work?" Their answer routes you.

## Red flags — propose the gate (do not silently skip)

These thoughts usually mean you are about to skip the gate without an explicit user opt-out. Don't. Propose the design trail; if the user wants to skip, they can say `/skip-design`.

| Thought | Reality |
|---|---|
| "It's just a small feature" | Small features compound into design debt. Five minutes of brainstorming saves an hour of rework. |
| "The user clearly wants X, let me just build it" | "Clearly" usually means "I'm projecting." Propose the trail and let the user decide. |
| "It's a prototype, design doesn't matter" | Especially for prototypes. Throwaway code only stays throwaway if you scoped it to be. |
| "I can scaffold the project and brainstorm in parallel" | No. Scaffolding decisions (renderer, autoloads, layers) depend on the GDD. |
| "The user said 'just build a platformer'" | Genre is one input. Pillars, scope, target, art direction are not. Offer the brainstorm; opt-out is theirs. |

## Order of operations for a new request

1. Read this skill (you're here).
2. Decide: design work or maintenance? (See "When the rule does/doesn't apply".)
3. If design, pick the trail by checking whether the project already has Godot source files:
   - **Trail A — greenfield** (no `project.godot`, or whole-game redesign):
     - Invoke `game-brainstorming`. Run the structured Q&A.
     - Invoke `gdd-writer`. Wait for GDD approval.
     - Invoke `writing-game-plan`. Wait for plan approval.
   - **Trail B — feature on existing game** (`project.godot` exists, change is bounded):
     - Invoke `codebase-survey`. Produces `docs/features/<date>-<slug>-survey.md`.
     - Invoke `feature-spec`. Wait for spec approval.
     - Invoke `feature-plan`. Wait for plan approval.
4. Only now: invoke implementation skills, milestone by milestone, per the plan.
5. After each milestone: update plan `Status`. Run `gut-test-writer`. Confirm with user before next milestone.

## Interaction with `paths` auto-loading

This skill is loaded by Claude Code whenever the conversation touches a `.gd`, `.tscn`, `.tres`, `.gdshader`, `project.godot`, or a GDD/plan markdown file. That covers every realistic Godot session. The `godot-patterns` skill is also `paths`-loaded — both apply, no conflict.
