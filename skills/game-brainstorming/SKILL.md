---
name: game-brainstorming
description: "MUST run before any Godot scaffolding, scene creation, component generation, or genre-pack invocation. Turns a game idea into an approved Game Design Document (GDD) and an approved implementation plan, through a structured one-question-at-a-time dialogue tailored to game development (genre, platform, scope, core loop, art / audio direction). Hard-gates implementation skills until both artifacts are approved."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Game Brainstorming — design before code

Turn a vague idea into an approved GDD plus an approved implementation plan, through collaborative dialogue.

<HARD-GATE>
You MUST NOT invoke any of these skills, write any `.gd` / `.tscn` / `project.godot` content, or run any scaffolding command until BOTH a GDD and an implementation plan have been written and explicitly approved by the user:

- `bootstrap-godot-project`
- `create-scene`, `create-component`, `create-state-machine`, `create-resource`, `create-autoload`
- `setup-collision-layers`, `setup-input-map`, `setup-save-system`, `setup-localization`
- `genre-pack-platformer`, `genre-pack-topdown`, `genre-pack-3d-action`, `genre-pack-turnbased`
- `shader-writer`, `sfx-generator`, `export-config`

This applies to EVERY project regardless of perceived simplicity, including jam games, prototypes, and "I just want to test something." Skipping this step is the single largest source of wasted work in game dev — feature creep, mismatched art, throw-away code paths, mechanics that don't serve the core loop.

Exceptions: read-only skills (`godot-patterns`, `performance-audit`), maintenance skills (`update-docs`, `gut-test-writer`, `gdscript-migrator`), and analysis agents (`code-reviewer`, `playtest-analyst`) may run without a brainstorm.
</HARD-GATE>

## Checklist

Create a task per item. Complete in order:

1. **Explore project context** — list files, read `README.md` / `docs/` if present, run `git log --oneline -20` if it's a git repo. Detect whether this is greenfield (no `project.godot`) or extending an existing project.
2. **Confirm scope class** — jam (≤72h), prototype (1–4 weeks), vertical slice (1–3 months), full game. Different scopes warrant different depth of brainstorm.
3. **Ask clarifying questions one at a time** — see "Question playbook" below. Cover all relevant dimensions.
4. **Propose 2–3 design directions** — with trade-offs. Recommend one. Ask user to pick.
5. **Present GDD outline section by section** — get user approval after each section before moving on.
6. **Write the GDD** — invoke `gdd-writer` skill to save under `docs/design/<YYYY-MM-DD>-<slug>-gdd.md`.
7. **Spec self-review** — re-read the saved GDD. Check for placeholders (`TBD`, `???`), contradictions, ambiguity, scope creep beyond the agreed scope class. Fix inline.
8. **User reviews the GDD file** — ask user to read the saved file and confirm or request changes.
9. **Hand off to `writing-game-plan`** — that skill produces the implementation plan and applies its own user-approval gate. Brainstorming ends here.

## Process flow

```
Greenfield or extending? ──► Scope class? ──► Q&A loop ──► 2–3 directions
                                                                │
                       ◄── User approves ──── GDD section-by-section ─┘
                                │
                                ▼
                       Write GDD (gdd-writer)
                                │
                                ▼
                       Self-review + fix inline
                                │
                                ▼
                       User approves saved file?
                          │            │
                       no │            │ yes
                          └─► revise ──┴─► writing-game-plan
```

## Question playbook

Ask **one question per message**. Prefer multiple-choice options. Don't ask everything below — ask only what is unclear and load-bearing for design decisions.

### Always ask

- **Genre + reference titles**: "Closest reference games (1–3 titles)? Any genre tag you'd put on the box?" — anchors the design in concrete examples.
- **Target platform(s)**: Desktop / mobile / web / console / multiple? Forces renderer choice (Forward Plus / Mobile / Compatibility), input model, and export config decisions.
- **Scope class**: jam / prototype / vertical slice / full game. Caps everything downstream.
- **Core loop in one sentence**: "Player does X → gets Y → uses Y to do more X." If the user can't state it, the loop doesn't exist yet — that's the priority.
- **Win / fail / progression structure**: how does a session end, and what carries over?

### Ask if relevant

- **Perspective / camera**: 2D side-scroll / 2D top-down / 2.5D / 3D third-person / 3D first-person / fixed camera.
- **Player count**: SP / local co-op / online co-op / online competitive. Networking changes architecture significantly — flag if user says "online."
- **Combat**: yes / no / what kind (melee, ranged, magic, mixed)? Drives Hurtbox/Hitbox layers and EventBus combat signals.
- **Inventory / progression**: items, abilities, stats, leveling, skill trees? Drives `create-resource` choices.
- **Saves**: required (story, long sessions) / optional (run-based) / none (arcade)? Drives `setup-save-system` use.
- **Procedural vs hand-authored content**: changes level workflow.
- **Art direction**: pixel art / 2D vector / hand-painted / low-poly 3D / stylized 3D / photoreal 3D. Drives texture filter, shader recipes, asset pipeline.
- **Audio direction**: chiptune / orchestral / ambient / licensed tracks / dialogue-heavy. Drives bus layout in `sfx-generator`.
- **Languages shipping at launch**: single / multi (which?). Drives `setup-localization`.
- **Accessibility targets**: colorblind, remappable input (always yes for keyboard+gamepad games), subtitles, scalable UI.
- **Monetization**: free / paid / F2P / DLC. Affects scope, telemetry, store requirements.
- **Pillars (3 max)**: short phrases the team can use to say "no" to feature creep. Example: "tactile combat, every fight tells a story, no filler."

### Decomposition trigger

If the user's idea contains ≥4 independent subsystems (e.g., "an MMO with crafting, housing, PvP arenas, and pet breeding"), STOP asking detail questions. Tell the user the scope is too large for one design pass. Propose decomposition into sub-projects, each with its own brainstorm → GDD → plan cycle. Get agreement on the first sub-project before proceeding.

## Direction proposals

Once the questions converge, present **2–3 distinct directions** before writing the GDD. Format:

```markdown
### Direction A: <one-line tagline>
**Pillars**: ...
**Core loop**: ...
**Risks**: <main risk 1>, <main risk 2>
**Why this fits**: ...

### Direction B: <one-line tagline>
... (same shape) ...

**Recommendation**: <A | B | C>, because <one paragraph>.
```

Then ask: "Which direction (or hybrid) do you want me to flesh out?"

## GDD outline (drives section-by-section approval)

Get explicit approval after each section before writing the next. Sections:

1. **One-pager** — title, genre, pillars, target platforms, scope class, elevator pitch.
2. **Core loop** — bullet steps, with the loop diagrammed if useful.
3. **Mechanics** — list each, one paragraph each, marked `[CORE]` or `[STRETCH]`.
4. **Systems** — saves, progression, inventory, combat, AI, etc. — only those that exist.
5. **Content scope** — count of levels / enemies / items / cutscenes / characters at v1.0.
6. **Art + audio direction** — palette / silhouette rules / reference images; bus layout sketch.
7. **UX** — input scheme, accessibility, language list.
8. **Risks + open questions** — what's still unknown, what could blow up the schedule.
9. **Out of scope** — explicit list of "we are NOT doing X." The most important section: it gives every later "wouldn't it be cool if…" a clean refusal.

Mark assumptions as `[HYPOTHESIS]` (per `gdd-writer` convention) so they can be validated later.

## Self-review checklist

After saving the GDD, re-read it and check:

- [ ] No `TBD` / `???` / `<placeholder>` left
- [ ] Pillars consistent across all sections
- [ ] Mechanics serve at least one pillar
- [ ] Scope class consistent — no `[CORE]` items that obviously exceed it
- [ ] Out-of-scope section is non-empty
- [ ] Every `[HYPOTHESIS]` has a "validated by:" plan (playtest, prototype, research)

Fix inline before handing to the user for review.

## Handoff to `writing-game-plan`

Once the user approves the saved GDD, invoke `writing-game-plan` and pass the GDD path. That skill produces an implementation plan with milestones mapped to the existing godot-superpowers skills, and applies its own user-approval gate before any code is written.

**Brainstorming terminates here.** Do NOT invoke `bootstrap-godot-project` or any genre pack directly from this skill.
