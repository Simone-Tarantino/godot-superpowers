---
name: codebase-survey
description: "Read-only survey of an existing Godot project before designing a new feature. Maps the scenes, scripts, autoloads, resources, and signals the feature will touch into `docs/features/<YYYY-MM-DD>-<slug>-survey.md`. Run BEFORE `feature-spec` whenever a feature lands on top of existing code; skip only for trivial one-file changes."
allowed-tools: Read, Grep, Glob, Write
argument-hint: <slug>
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Codebase Survey

Maps the parts of an **existing** Godot project that a planned feature will touch. Output anchors the downstream `feature-spec` and `feature-plan` to real files, real APIs, and real risks — not to memory or wishful thinking.

**Core rule:** read-only. This skill never edits `.gd`, `.tscn`, `.tres`, or `.gdshader`. It writes exactly one file: `docs/features/<YYYY-MM-DD>-<slug>-survey.md`.

## When to invoke

- A user asks to add / change / extend a feature on a project that already has code.
- The change touches 2+ files OR 1+ autoload OR 1+ existing scene.
- Before `feature-spec` — survey is the input the spec depends on.

Skip the survey for:
- **Trivial features** under the shared shortcut: touches one file AND adds no new mechanic AND adds no new public surface (no new signal / exported var / autoload / input action). In that case, `feature-spec` records `Survey reference: none (trivial shortcut)` and `feature-plan` accepts the same string. Any of the three conditions failing makes the survey mandatory.
- Greenfield projects (no code yet — use `game-brainstorming` → `gdd-writer` instead).
- Read-only investigations (use the `Explore` agent).

## File path convention

- **Location**: `docs/features/`
- **Filename**: `<YYYY-MM-DD>-<slug>-survey.md`
  - Date is the day the survey is written.
  - Slug is kebab-case of the feature working title (e.g. `2026-05-12-double-jump-survey.md`).
- **One survey per feature.** When re-surveying after major project changes, write a NEW dated file rather than editing — keep the trail.
- The matching `feature-spec` and `feature-plan` reuse the same `<YYYY-MM-DD>-<slug>` prefix:
  - `docs/features/<YYYY-MM-DD>-<slug>-feature.md`
  - `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md`

## Inputs

- The user's feature description (one or two sentences is fine — survey expands it).
- The existing project tree (`project.godot`, `scenes/`, `scripts/`, `autoload/`, `resources/`).
- The latest GDD (`docs/design/*-gdd.md`) if one exists — link it so the spec inherits design pillars.

## Workflow

1. **Resolve project root.** Confirm `project.godot` is at the repo root or known subdir.
2. **Sweep with `Glob`/`Grep`** for keywords from the feature description (mechanic names, class names, signal names the user mentioned). Capture file paths only.
3. **Read each candidate file** (script + scene) to extract: `class_name`, exported vars, signals emitted/connected, public methods.
4. **Trace integration points.** For each touched script, grep the rest of the project for callers / signal subscribers — these are the regression hotspots.
5. **Detect gaps.** If a referenced node, autoload, or input action does not yet exist, list it under "New surface needed" — the spec will declare it intentionally.
6. **Write the survey markdown.** Sections below.

## Survey template

Save to `docs/features/<YYYY-MM-DD>-<slug>-survey.md`:

```markdown
# Feature Survey — <Feature Working Title>

- **Slug**: <kebab-case>
- **Date**: <YYYY-MM-DD>
- **Author**: <user> + Claude (godot-superpowers)
- **GDD reference**: docs/design/<YYYY-MM-DD>-<slug>-gdd.md (or "none — to be written")
- **Status**: Draft

## Feature in one line

<One sentence — what the user wants. No solution, just the goal.>

## Touched scenes

| Path | Role | Why touched |
|------|------|-------------|
| `scenes/player/player.tscn` | Player root | New animation state |
| `scenes/ui/hud.tscn` | HUD | New cooldown indicator |

## Touched scripts

| Path | `class_name` | Public API relevant to the feature |
|------|--------------|-------------------------------------|
| `scripts/player/player.gd` | `Player` | `signal jumped`, `func jump() -> void`, `@export var jump_velocity: float` |
| `scripts/components/health_component.gd` | `HealthComponent` | `signal died`, `func take_damage(amount: int) -> void` |

## Touched autoloads

| Singleton | Path | Method / signal the feature relies on |
|-----------|------|----------------------------------------|
| `EventBus` | `autoload/event_bus.gd` | `signal player_died` |
| `SaveManager` | `autoload/save_manager.gd` | `func save_state() -> void` |

## Touched resources

| Path | Resource class | Fields the feature reads / extends |
|------|----------------|-------------------------------------|
| `resources/player_stats.tres` | `PlayerStats` | `max_jumps` (extend from 1 → 2) |

## Integration points (existing code → feature)

- `EventBus.player_died` is connected by `ui/game_over.tscn::_on_player_died` and `audio/audio_manager.gd::_on_player_died`. Feature must not break either.
- `Player.jump()` is called by `scripts/player/player.gd::_unhandled_input` and `tests/unit/test_player.gd`.
- Add fan-out / fan-in callouts wherever a method or signal has 2+ subscribers.

## New surface needed (does not yet exist)

- New input action: `dash` (to register via `setup-input-map`).
- New scene: `scenes/effects/dash_trail.tscn`.
- New signal: `Player.dashed(direction: Vector2)`.

If this list is empty, the feature is purely additive on existing surface — call that out explicitly.

## Regression hotspots

Files with **3+ external references** in the project. Touching them risks unintended impact. The `feature-plan` must include regression tests for each.

| File | Reference count | Why hot |
|------|------------------|--------|
| `scripts/player/player.gd` | 14 | Used by enemies, UI, audio, tests |
| `autoload/event_bus.gd` | 22 | Project-wide signal hub |

## Open questions for the spec

- `[OPEN]` Should the cooldown be tunable via `PlayerStats` resource, or hardcoded?
- `[OPEN]` Does the existing animation tree already have a `dash` state, or does it need a new branch?

Each open question becomes a decision point in `feature-spec`.

## Survey complete — handoff

Next skill: `feature-spec`. Path that the spec will write:

    docs/features/<YYYY-MM-DD>-<slug>-feature.md
```

## Writing rules

- **Read-only.** No `Edit`, no `Write` outside the single survey file.
- **Concrete paths only.** `scripts/player/player.gd`, not "the player script". If a path is unknown, mark `[NOT FOUND]` — the spec will decide whether to create it.
- **Public API surface only.** Do not transcribe private methods or implementation details — that's noise. The spec/plan re-read the file when they need internals.
- **No code blocks** in the survey except short signal/method signatures (`signal jumped(velocity: float)`). Save full code for `feature-plan` and the implementation skills.
- **No design decisions.** "We should add X" belongs in `feature-spec`. The survey only states what exists and what's missing.
- **Tag uncertainties `[OPEN]`** — every `[OPEN]` becomes a question for the spec.

## Anti-patterns to avoid

| Anti-pattern | Why bad | Fix |
|--------------|---------|-----|
| Surveying the entire project | Scope creep, wasted tokens | Scope to files matched by the feature description's keywords |
| Including full method bodies | Noise — the survey is a map, not a copy | Method signatures only |
| Recommending a solution | The spec owns design | List facts and `[OPEN]` questions |
| Skipping regression hotspots | Most rework comes from unflagged fan-in | Always grep callers for every touched script |
| Writing prose paragraphs | Unscannable | Tables and bullet lists |
| Editing existing files | Out of scope — survey is read-only | Write only the survey markdown |

## Cross-references

- `feature-spec` — consumes the survey and produces the design doc.
- `feature-plan` — consumes both, produces the implementation plan.
- `update-docs` — cross-checks survey ↔ spec ↔ plan ↔ code after merge.
- For greenfield projects use `gdd-writer` + `writing-game-plan` instead — the survey/spec/plan trio is for **changes on top of existing code**.
