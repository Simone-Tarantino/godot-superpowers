---
name: feature-spec
description: "Write a feature specification at `docs/features/<YYYY-MM-DD>-<slug>-feature.md` for a single bounded feature on an existing Godot project. Use AFTER `codebase-survey` and BEFORE `feature-plan`. Soft-gates implementation skills (opt-out via `/skip-design`). NOT for greenfield design (use `gdd-writer`) and NOT for technical decomposition (use `feature-plan`)."
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: <slug> | section
---

# Feature Spec

Surgical design document for **one bounded feature** added to an **existing** game. Lives between the GDD (whole game) and the plan (technical decomposition).

<SOFT-GATE>
By default, do not invoke implementation skills (`bootstrap-godot-project`, `create-*`, `setup-*`, `genre-pack-*`, `shader-writer`, `sfx-generator`, `export-config`) until BOTH a feature spec AND a feature plan exist for the feature, and the user has explicitly approved them. The feature plan is produced by the `feature-plan` skill that runs after this one. Opt-out: the user may bypass with `/skip-design` — warn once that bounded features still benefit from a 5-minute spec to catch regression-risk before code, get a confirmation, then proceed.
</SOFT-GATE>

## When to invoke

- After `codebase-survey` finishes, on a project that already has code.
- The change is bounded enough to fit in one document (one mechanic, one system tweak, one UI screen).
- A GDD already exists for the project — the feature inherits its pillars.

Do NOT use this skill for:
- **Greenfield projects** — use `game-brainstorming` → `gdd-writer` (full GDD).
- **Cross-cutting refactors touching every system** — that's a re-plan; escalate to Trail A: redo `game-brainstorming` → `gdd-writer` → `writing-game-plan` from scratch. Do NOT silently mutate a feature spec into a whole-game plan.
- **Bug fixes with a known repro** — direct edit + `code-reviewer`.

## File path convention

- **Location**: `docs/features/`
- **Filename**: `<YYYY-MM-DD>-<slug>-feature.md` (same `<YYYY-MM-DD>-<slug>` prefix used by the matching survey).
- **One spec per feature.** Major scope rewrites get a NEW dated file; never edit historical specs.
- The plan file is `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md` and references this spec by path.

## Inputs

- The survey: `docs/features/<YYYY-MM-DD>-<slug>-survey.md` — **strongly recommended, optional only under the trivial-feature shortcut below**.
- The current GDD: `docs/design/*-gdd.md` (latest).
- The user's feature description (one or two sentences).

## Trivial-feature shortcut (single rule, mirrored in `feature-plan`)

A feature qualifies as **trivial** if and only if ALL of these hold:

1. Touches exactly **one** file.
2. Adds **no** new mechanic (no `[HYPOTHESIS]` block).
3. Adds **no** new public surface (no new signal, no new exported var, no new autoload, no new input action).

If trivial:
- Skip `codebase-survey` entirely.
- In this spec, fill only `Problem`, `Player-facing change`, `Acceptance criteria`, `Rollback plan`. Keep the file under 30 lines.
- In the spec header, set `Survey reference: none (trivial shortcut)` exactly — `feature-plan` keys off this string to allow a missing survey.

If any of the three conditions fails, the survey is **mandatory** — write it before drafting the spec. The hard implementation gate applies regardless of trivial / non-trivial.

## Spec structure

Save to `docs/features/<YYYY-MM-DD>-<slug>-feature.md` with these sections:

### 1. Header

```markdown
# Feature Spec — <Feature Working Title>

- **Slug**: <kebab-case>
- **Date**: <YYYY-MM-DD>
- **Author**: <user> + Claude (godot-superpowers)
- **GDD reference**: docs/design/<YYYY-MM-DD>-<slug>-gdd.md
- **Survey reference**: docs/features/<YYYY-MM-DD>-<slug>-survey.md  *(or exactly `none (trivial shortcut)` if the trivial-feature shortcut applies — see "Trivial-feature shortcut" below)*
- **Status**: Draft | Approved | In Progress | Done
```

### 2. Problem

One short paragraph: **why** the feature exists. Player pain, design gap, GDD pillar under-served. No solution yet.

> **Rule**: if the problem can't be stated without naming the solution, the problem is not yet understood — go back and dig.

### 3. Player-facing change

What the player sees, feels, and does that they couldn't before. Use design language ("the Hero leaps a second time mid-air"), not code language ("`Player.jump()` checks `jump_count`").

### 4. Scope IN

Bullet list — exactly what this feature delivers.

### 5. Scope OUT

Bullet list — what is **explicitly** not in this feature. Anti-scope-creep clause. Common entries: extra polish, related-but-separate ideas, full new genre packs.

### 6. Integration with existing systems

| Existing element | How the feature interacts |
|------------------|----------------------------|
| GDD pillar "Frantic mobility" | Feature reinforces it (more options mid-air) |
| `HealthComponent` | Feature subscribes to `damaged` to cancel itself |
| Save system | New tunable persists via existing `PlayerStats` resource |

If the feature contradicts a pillar, **stop and revisit** — either the pillar is wrong or the feature is.

### 7. New mechanics (only if any)

For each net-new mechanic, reuse the `gdd-writer` mechanic template:

```markdown
## [HYPOTHESIS] {Mechanic Name}

One- to three-sentence description.

**How it works:**
- What the player does / sees
- How it integrates with existing mechanics
- What decisions / consequences it creates

**Why this mechanic:**
Tie to a GDD pillar. If it doesn't reinforce one, cut it.

**Risks:**
- Balance, feel, complexity creep.
```

After playtesting, when the spec is closed, drop the `[HYPOTHESIS]` tag and migrate the entry into the GDD's Mechanics section (the `update-docs` skill flags this).

### 8. Regression risks

Lift directly from the survey's "Regression hotspots" + "Integration points". For each, state what the feature must not break.

| Hotspot | What must keep working |
|---------|------------------------|
| `Player.jump()` callers | Existing single-jump behavior unchanged when feature disabled |
| `EventBus.player_died` subscribers | Feature does not reorder or block emission |

### 9. Acceptance criteria

Bullet, testable, behavior-only. These feed into `feature-plan` (test plan) and `file-verifier`.

```markdown
- [ ] In-air, pressing jump within `jump_buffer` window after the first jump triggers a second jump.
- [ ] After the second jump, no further jumps occur until landing.
- [ ] Landing on any surface tagged `floor` resets jump count to 0.
- [ ] Existing single-jump tests still pass.
```

### 10. Tuning numbers

Design intent only. Exact tuning lives in `.tres` resources or constants. Always pair a number with its rationale.

```markdown
- `max_jumps = 2` — pillar "Frantic mobility" demands aerial expressiveness without trivializing platforming.
- `jump_buffer = 0.12s` — matches existing buffer for input parity.
```

### 11. Rollback plan

How to disable / undo the feature if it ships and breaks something. Examples:
- "Set `PlayerStats.max_jumps = 1` to revert behavior — code path unchanged."
- "Remove autoload `DashManager` and the input action `dash` — no migration needed."
- "Feature is a new scene only; deleting it has zero effect on existing scenes."

If you cannot describe a rollback, the feature is too entangled — split it.

### 12. Open questions

Lift each `[OPEN]` from the survey, add new ones surfaced by the spec. Each must resolve before the user marks the spec `Approved`.

## Writing rules

- **No class names, no file paths, no code.** Those live in `feature-plan`.
- **One feature per spec.** If two changes ship together but are independent, write two specs.
- **Tag uncertain claims `[HYPOTHESIS]`.** Drop the tag once playtested.
- **Numbers stay in the spec for design intent**; exact tuning lives in `.tres` constants.
- **Reference the GDD by path.** Never restate the GDD inside the spec.

## Anti-patterns to avoid

| Anti-pattern | Why bad | Fix |
|--------------|---------|-----|
| Code or class names in the spec | Implementation detail; rots fast | Move to `feature-plan` |
| Solution dressed as problem | Hides the real player pain | Restate problem without naming the fix |
| Empty Scope OUT | Scope creep guaranteed | Force at least 2 entries |
| Missing rollback plan | Feature can't be cleanly retracted | Add it or split the feature |
| Restating the GDD inline | Doubles the maintenance surface | Reference by path |
| Confirmed mechanics without playtest | False certainty | Keep `[HYPOTHESIS]` until validated |

## Approval gate

Walk the user through the spec section by section. After each, ask: "Approve this section, change it, or skip?"

When all sections are approved, ask the user to flip `Status: Approved`. Then hand off to `feature-plan`.

## Cross-references

- `codebase-survey` — produces the input survey.
- `feature-plan` — consumes this spec to produce the technical plan.
- `gdd-writer` — owns whole-game design; mechanic template is reused here.
- `update-docs` — after merge, syncs spec ↔ GDD (promotes confirmed `[HYPOTHESIS]` mechanics into the GDD).
