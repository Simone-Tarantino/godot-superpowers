---
name: writing-game-plan
description: "Run after game-brainstorming has produced an approved GDD. Produces a milestone-based implementation plan that maps every step to a specific godot-superpowers skill, identifies vertical slices, and soft-gates implementation behind user approval (opt-out via `/skip-design`). Should run before any scaffolding, scene creation, or genre-pack invocation."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: <path-to-gdd-file>
---

# Writing a Game Plan

Convert an approved Game Design Document into an actionable, milestone-based implementation plan that uses the godot-superpowers skill catalog as its building blocks.

<SOFT-GATE>
By default, do not invoke implementation skills (`bootstrap-godot-project`, `create-*`, `setup-*`, `genre-pack-*`, `shader-writer`, `sfx-generator`, `export-config`) until the plan produced by this skill has been written to `docs/plans/<YYYY-MM-DD>-<slug>-plan.md` and explicitly approved by the user. Opt-out: the user may bypass with `/skip-design` (or any clear equivalent) — warn once that mismatched scope is the typical failure mode, get a confirmation, then proceed.
</SOFT-GATE>

## When to invoke

- Immediately after `game-brainstorming` finishes (the standard handoff).
- When picking up an existing project that already has a GDD but no plan.
- When re-planning after a major scope change (write a NEW plan; do not edit the old one — keep the trail).

## Inputs

- **The GDD** (passed as argument, or located via `docs/design/*-gdd.md`). Read it fully before drafting.
- **Current project state** — `git status`, `ls`, presence of `project.godot`, autoloads already registered, addons already installed. The plan must start from where the project actually is.

## Plan structure

Save to `docs/plans/<YYYY-MM-DD>-<slug>-plan.md`. Required sections:

### 1. Header

```markdown
# Implementation Plan — <Game Title>

- **GDD**: docs/design/<YYYY-MM-DD>-<slug>-gdd.md
- **Scope class**: jam / prototype / vertical slice / full game
- **Target platforms**: ...
- **Author**: <user> + Claude (godot-superpowers)
- **Date**: <YYYY-MM-DD>
- **Status**: Draft | Approved | In Progress | Done
```

### 2. Pillars + non-goals (copied verbatim from GDD)

So the plan can be read in isolation. If a milestone item conflicts with a pillar or hits a non-goal, the plan is wrong.

### 3. Milestones

Each milestone is a **demo-able checkpoint** — something the user could play / watch / show. Number them M0, M1, …

For each milestone, document:

```markdown
## M2 — Vertical slice combat (target: 2 weeks)

**Demo criterion**: Player can enter a single arena, fight 3 enemies, win or die, return to main menu.

**Skills invoked, in order**:
1. `setup-collision-layers` — confirm Hurtbox/Hitbox layers
2. `create-component` HealthComponent + HurtboxComponent2D + HitboxComponent2D
3. `create-scene` 2d-enemy Slime
4. `create-state-machine` enemy AI: Idle → Chase → Attack → Hurt → Dead
5. `gut-test-writer` — tests for HealthComponent damage application

**Deliverables**:
- `scenes/enemies/slime.tscn`
- `scripts/components/health_component.gd` + tests
- `scenes/levels/arena_01.tscn`

**Risks**:
- Hitbox tuning may need iteration after first playtest
- Animation timing locked to attack frames — flag if missing art

**Definition of done**:
- [ ] Demo criterion playable from `main.tscn` without crashes
- [ ] `gdlint` clean on touched files
- [ ] GUT tests green
- [ ] Build runs on at least one target platform from `export-config`
```

### 4. Skill dependency map

A short DAG / list showing which skills depend on which milestones.

```
M0 bootstrap → M1 input/saves → M2 combat slice → M3 progression → M4 content → M5 polish + export
```

### 5. Cut list

Explicit "if behind schedule, cut these in order." Items should be `[STRETCH]` from the GDD; if you find yourself cutting `[CORE]` items, the scope class was wrong — escalate to the user.

### 6. Open questions

Anything from the GDD's `[HYPOTHESIS]` markers that the plan needs to validate, with the milestone it's tied to.

## Sequencing rules

The plan must respect these dependencies, in this order:

1. **Foundation always first**: `bootstrap-godot-project` → `setup-collision-layers` → `setup-input-map`. No combat / movement / scene work before these.
2. **Save system early IF saves are required**: `setup-save-system` lives in M0 or M1. Retrofitting saves after content exists costs more than the original feature.
3. **Localization before UI is finalized IF multi-language at launch**: `setup-localization` in M0 / M1. Hardcoded English in `.tscn` files is the most common avoidable rework.
4. **Genre pack before player polish**: pick exactly one of `genre-pack-platformer` / `topdown` / `3d-action` / `turnbased` and invoke it before iterating on player feel. Mixing genre packs is allowed but flag it as a risk.
5. **`export-config` last but not optional**: every plan must have a milestone where a real build runs on a real device. If the plan ends without that, it's a tutorial, not a game.
6. **Tests track features**: each combat / save / progression milestone has a `gut-test-writer` step in its skill list. Don't bank tests for a "polish" milestone at the end — they accrue interest.

## Vertical slice rule

For prototypes / vertical slices / full games, **M2 must be a vertical slice**: one level + one enemy + one mechanic, fully polished, exportable. M3+ scales the slice. This catches integration failures early. Flag the plan as "no vertical slice" only for jam-scope projects.

## Self-review checklist

Before presenting the plan to the user:

- [ ] Every milestone has a demo criterion (something playable)
- [ ] Every skill listed exists in the godot-superpowers catalog (run `ls skills/`)
- [ ] No skill is invoked before its dependencies (per Sequencing rules)
- [ ] Cut list is non-empty for non-jam scope
- [ ] At least one `gut-test-writer` step per major mechanic
- [ ] At least one `export-config` step
- [ ] Total estimated weeks fits the scope class (jam ≤ 2 weeks, prototype ≤ 4, slice ≤ 12, full game has no cap but escalate if M-count > 8)

Fix inline. Then present sections to the user for approval.

## User approval gate

Walk the user through the plan section by section. After each section, ask: "Approve this section, change it, or skip?"

Once every section is approved, ask the user to mark the file `Status: Approved`. Only then can implementation skills be invoked. Reference the plan path in subsequent skill invocations so the work stays traceable.

## After approval

- Switch to executing the first milestone.
- Update the plan's `Status` field as work progresses (`In Progress`, then `Done` per milestone).
- After each milestone's demo criterion is met, do a quick retro inline in the plan: "What surprised us?" → feeds the next milestone's risk section.
- Do NOT silently re-plan. If the plan must change mid-flight, write a new plan file and link it from the old one.
