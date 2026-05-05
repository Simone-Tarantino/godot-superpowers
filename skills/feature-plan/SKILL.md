---
name: feature-plan
description: "Convert an approved feature spec into a milestone-based technical implementation plan at `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md`. Maps the spec to concrete files (create / edit / delete), worker decomposition, and regression tests. Required before `orchestrator` dispatch on existing-game features. Run AFTER `feature-spec`."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: <path-to-feature-spec>
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Feature Plan

Converts an approved feature spec into an actionable, milestone-based implementation plan that uses the godot-superpowers skill catalog as building blocks. Counterpart of `writing-game-plan` for **changes on top of existing code**.

<HARD-GATE>
You MUST NOT invoke any implementation skill (`bootstrap-godot-project`, `create-*`, `setup-*`, `genre-pack-*`, `shader-writer`, `sfx-generator`, `export-config`) until the plan produced by this skill has been written to `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md` and explicitly approved by the user. The orchestrator agent enforces the same precondition.
</HARD-GATE>

## When to invoke

- Immediately after `feature-spec` has been approved by the user (the standard handoff).
- When picking up a feature that already has a spec but no plan.
- When re-planning after a major scope change to the spec — write a NEW plan file; do not edit the old one.

## Inputs

- The feature spec (passed as argument, or located via `docs/features/*-feature.md` of the same slug). Read it fully. The spec's header `Survey reference:` field is canonical:
  - If it points to a survey file path, that survey is **mandatory input** — read it fully; it dictates which existing files the plan touches.
  - If it is exactly `none (trivial shortcut)`, the trivial-feature shortcut is in effect (see below). No survey input is required.
  - Any other value is a **drift error** — stop and route the user back to `feature-spec` to repair the header before planning.
- Current project state — `git status`, `ls`, autoloads registered, addons installed.

## Trivial-feature shortcut (mirrored from `feature-spec`)

A feature is trivial iff ALL of: touches one file, adds no new mechanic, adds no new public surface (no new signal / exported var / autoload / input action). The `feature-spec` declares this by writing `Survey reference: none (trivial shortcut)` in the spec header.

When the shortcut is in effect, this plan:
- Sets `Scope class: micro (1 file)` in the header.
- Skips the "Files: create" and "Files: delete" tables (write `(none)` in each, never omit them).
- Reduces "Files: edit" to a single row.
- Skips the "Cut list" section (write "(not applicable — trivial)").
- Still requires a populated "Test plan", "Rollback plan", "Self-review checklist", and `<orchestrator-state>` placeholder. The hard gate still applies.

If any of the three trivial conditions becomes false during planning (the diff turns out to need a new signal, a second file, or a new mechanic), stop, route the user back to `feature-spec` to drop the trivial shortcut, write the survey, and replan from a non-trivial spec — do NOT silently expand the plan.

## File path convention

- **Location**: `docs/plans/`
- **Filename**: `<YYYY-MM-DD>-<slug>-feature-plan.md` (same `<YYYY-MM-DD>-<slug>` prefix as the spec and survey).
- **Suffix `-feature-plan.md`** distinguishes feature-scope plans from full-game plans (`<slug>-plan.md`). The orchestrator accepts either suffix.

## Plan structure

Save to `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md` with these required sections:

### 1. Header

```markdown
# Feature Plan — <Feature Working Title>

- **Spec**: docs/features/<YYYY-MM-DD>-<slug>-feature.md
- **Survey**: docs/features/<YYYY-MM-DD>-<slug>-survey.md  *(or exactly `none (trivial shortcut)` — copy this verbatim from the spec's `Survey reference:` field)*
- **GDD**: docs/design/<YYYY-MM-DD>-<slug>-gdd.md
- **Scope class**: micro (1 file) / small (2-5 files) / medium (6-15 files) / large (16+ — split into smaller features)
- **Author**: <user> + Claude (godot-superpowers)
- **Date**: <YYYY-MM-DD>
- **Status**: Draft | Approved | In Progress | Done
```

### 2. Acceptance criteria (copied verbatim from spec)

So the plan can be read in isolation. The orchestrator copy-pastes these into worker prompts and the file-verifier checks against them.

### 3. File touch list

Three tables — every file the feature creates, edits, or deletes. The survey is the source of truth; if a file appears here that wasn't in the survey, flag it as new surface and confirm with the user before approval.

```markdown
**Files: create**

| Path | Skill that produces it | Acceptance ref |
|------|-------------------------|-----------------|
| `scripts/components/double_jump_component.gd` | `create-component` | AC #1, #2 |
| `tests/unit/test_double_jump_component.gd` | `gut-test-writer` | AC #1, #2, #3 |

**Files: edit**

| Path | One-line diff intent | Skill / agent | Acceptance ref |
|------|----------------------|---------------|-----------------|
| `scripts/player/player.gd` | Wire DoubleJumpComponent into jump flow | direct edit + `code-reviewer` | AC #1 |
| `resources/player_stats.tres` | Add `max_jumps: int = 2` | direct edit | AC #4 |

**Files: delete**

| Path | Reason |
|------|--------|
| (none) | — |
```

If the delete table is empty, write "(none)" — never omit it.

### 4. Milestones

Each milestone is a **demo-able checkpoint**. Number them M0, M1, …. For small features, **one milestone is enough** — do not pad the plan with synthetic phases.

```markdown
## M1 — Double-jump component lands and is hooked into Player

**Demo criterion**: Player can jump a second time mid-air; landing resets the count.

**Skills invoked, in order**:
1. `create-component` — DoubleJumpComponent (state, exposed `max_jumps`, signal `jumped(count: int)`)
2. direct edit + `code-reviewer` — wire component into `Player._unhandled_input` jump branch
3. `gut-test-writer` — unit tests for the component
4. `qa-tester` — regression pass on existing Player tests

**Deliverables**:
- `scripts/components/double_jump_component.gd`
- Edit: `scripts/player/player.gd`
- `tests/unit/test_double_jump_component.gd`

**Risks**:
- Existing jump tests may assert exact `velocity.y` after first jump — verify.
- Animation tree may need a `double_jump` blend — flag if missing art.

**Definition of done**:
- [ ] All acceptance criteria pass
- [ ] `gdlint` clean on touched files
- [ ] GUT tests green
- [ ] Existing single-jump tests still pass
- [ ] Rollback plan from spec verified manually (set `max_jumps = 1` → behavior reverts)
```

### 5. Test plan

Two flavors required:

| Flavor | What |
|--------|------|
| **New tests** | One GUT (or GdUnit4) test per acceptance criterion. Cover the new component, signal, or scene. |
| **Regression tests** | One test per regression hotspot from the survey. These guard existing behavior. |

If a hotspot has no existing test and the plan does not add one, flag the gap and decide with the user whether to backfill or accept the risk.

### 6. Cut list

Explicit "if behind schedule, cut these in order." Items must be `[STRETCH]` from the spec; if you find yourself cutting acceptance-criterion items, the spec scope was wrong — escalate.

### 7. Rollback plan (lift from spec, expand)

Restate the rollback from the spec, plus the **technical** undo: which files revert, which migrations are needed (if any), which save data needs cleanup.

### 8. Open questions

Lift unresolved `[OPEN]` items from the spec. Resolve them with the user before approval.

### 9. `<orchestrator-state>` block

Empty placeholder — the orchestrator fills it on dispatch:

```markdown
<orchestrator-state>
  milestone: M1
  phase: 0/1
  pending: []
  in_progress: []
  completed: []
  blocked_on: none
  fix_passes: {}
  last_updated: <YYYY-MM-DD HH:MM>
</orchestrator-state>
```

## Sequencing rules

The plan must respect these dependencies, in this order:

1. **Foundation gaps first.** If the survey's "New surface needed" lists a missing input action, autoload, or collision layer, run the matching `setup-*` / `create-autoload` skill in M0 BEFORE wiring the feature.
2. **Component / system before integration.** Create or extend the component in isolation, then wire it into the consuming scene — never both in one worker. Easier to verify and roll back.
3. **Regression tests before integration commits.** When a hotspot has no existing test, write one against current behavior FIRST so it captures pre-feature truth — then implement the feature and ensure the test still passes.
4. **Tests track the feature.** Every milestone has a `gut-test-writer` step. Don't bank tests for a final "polish" milestone.
5. **No genre-pack invocation in a feature plan.** Genre packs are foundational and belong in `writing-game-plan`. If a feature genuinely needs a genre pack, the user is doing greenfield work — route them to `game-brainstorming` instead.

## Self-review checklist

Before presenting the plan to the user:

- [ ] Every milestone has a demo criterion
- [ ] Every skill listed exists in the godot-superpowers catalog (run `ls skills/`)
- [ ] Every entry in "Files: edit" appears in the survey, or is flagged as new surface (skipped under the trivial shortcut — only the single edit row is required)
- [ ] Every acceptance criterion in the spec maps to at least one file in "Files: create" / "Files: edit"
- [ ] Test plan covers all acceptance criteria + all regression hotspots
- [ ] Cut list is non-empty for medium / large scope (micro / small can omit)
- [ ] Rollback plan is concrete (filenames, flags, save-data treatment)

Fix inline. Then present sections to the user for approval.

## User approval gate

Walk the user through the plan section by section. After each, ask: "Approve this section, change it, or skip?"

Once every section is approved, ask the user to flip `Status: Approved`. Only then can implementation skills be invoked. The orchestrator agent will refuse to dispatch until both the spec AND this plan are `Approved`.

## After approval

- Hand off to `orchestrator` for milestones with 3+ files or 2+ subsystems; otherwise invoke skills directly per the milestone "Skills invoked" list.
- Update the plan's `Status` field as work progresses.
- After each milestone's demo criterion is met, append a one-line retro: "What surprised us?" — feeds the next milestone's risk section.
- Do NOT silently re-plan. If the plan must change mid-flight, write a new plan file and link it from the old one.

## Cross-references

- `feature-spec` — produces the design input.
- `codebase-survey` — produces the file/integration map.
- `writing-game-plan` — full-game counterpart for greenfield work.
- `orchestrator` — accepts this plan as a precondition for milestone execution.
- `update-docs` — after milestone completion, syncs progress and promotes confirmed `[HYPOTHESIS]` mechanics into the GDD.
