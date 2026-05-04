---
name: using-godot-superpowers
description: "Auto-loaded dispatcher for godot-superpowers. Establishes the design-before-code rule: any creative game-development task (new project, new feature, new mechanic, new scene, new component, new genre pack, new shader, new audio system) MUST start with the game-brainstorming skill, which produces an approved GDD and plan before any implementation skill runs."
paths: ["**/*.gd", "**/*.tscn", "**/*.tres", "**/*.gdshader", "project.godot", "**/*-gdd.md", "**/*-plan.md"]
---

# Using godot-superpowers

This file loads automatically whenever Claude touches a Godot project (matched via `paths` above). Read it first.

## The rule

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
