---
name: gdd-writer
description: Write or update a Game Design Document (GDD.md) for the project. Use when adding mechanics, recording design decisions, or documenting scope. NOT for technical implementation — that lives in code and CLAUDE.md.
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: [section | all | new-mechanic]
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# GDD Writer

Maintains `GDD.md` (Game Design Document) at project root. Keeps **design** (what the game is and why) separate from **implementation** (how the code works).

**Core rule:** the GDD drives the code. If code diverges from the GDD, document the divergence in `PROGRESS.md` (or `NOTES.md`); never silently rewrite the GDD to match code.

## Standard GDD sections

If no `GDD.md` exists, create one with these sections. Skip sections that don't apply to the genre.

| Section | Content | Update when |
|---------|---------|-------------|
| **Concept (one line)** | High-level pitch, tagline | Vision changes |
| **Pillars** | 3–5 design pillars driving every decision | Foundational shift |
| **Tone & Identity** | Aesthetic, mood, references | Art/audio direction shifts |
| **Player Fantasy** | What the player is and what they feel | Core fantasy refined |
| **Genre & References** | Genre tags, comparables ("X meets Y") | Repositioning |
| **Core Loop** | The 30-second moment-to-moment loop | Loop refined |
| **Meta Loop** | Run/session structure, progression between sessions | Meta added/changed |
| **Mechanics** | Each mechanic: rule, input, output | Mechanic added/changed |
| **Systems** | How mechanics combine (combat, economy, AI) | System designed |
| **Controls** | Input scheme per device | Mapping changes |
| **Content** | Levels, characters, items, enemies (lists) | Content added |
| **Progression** | XP, unlocks, difficulty curve | Progression tuned |
| **Economy** | Currencies, sources, sinks, faucets | Economy changed |
| **Win/Lose Conditions** | Per session, per run, per arena | Conditions change |
| **Narrative** | Story beats, characters, world | Story drafted |
| **UI/UX** | Diegetic vs non-diegetic, key screens | UI redesigned |
| **Art Direction** | Palette, style, references | Art bible refined |
| **Audio Direction** | Music style, SFX philosophy | Audio direction set |
| **Scope** | What's in V1, what's cut, stretch goals | Scope decisions |
| **Open Questions** | `[HYPOTHESIS]` items still being playtested | Hypothesis confirmed/discarded |

## Writing rules

- **One section, one purpose.** Don't mix mechanics into narrative.
- **No code, no class names, no file paths.** That belongs in `CLAUDE.md` or `PROGRESS.md`.
- **Tables for structured data**, bullets for lists, prose for fantasy/tone.
- **Tag uncertain sections `[HYPOTHESIS]`** until validated through playtesting.
- **Numbers stay in the GDD** for design intent (e.g. "player has 3 jumps"), exact tuning lives in `.tres` resources or constants.

## Adding a new mechanic

Template:

```markdown
## [HYPOTHESIS] {Mechanic Name}

One- to three-sentence description of what the mechanic is and why it exists.

**How it works:**
- What the player does / sees
- How it integrates with existing mechanics
- What decisions / consequences it creates

**Why this mechanic:**
Tie to design pillars. If it doesn't reinforce a pillar, cut it or revise the pillar.

**Risks:**
- What could break? Balance, feel, complexity creep?

**Implementation order:**
Where this fits in the roadmap. Before/after the core loop is solid?
```

Drop `[HYPOTHESIS]` once validated through playtesting.

## Adding a content entry

Template (item, enemy, level — adapt fields):

```markdown
**{Name}** — {Type}, {Tag/Element}, {key stats}
*"{Flavor text — one line, in the voice of the world}"*
{Role in gameplay in one sentence.}
```

Example:

```markdown
**Frostfang Pendant** — Accessory, Ice, +15 AP, +5% crit
*"Cold to the touch, even in summer."*
Mid-game DPS amulet for ice mages — pairs with Glacier Strike.
```

## Anti-patterns to avoid

| Anti-pattern | Why bad | Fix |
|--------------|---------|-----|
| Code snippets in GDD | Mixes design with implementation, rots fast | Move to `CLAUDE.md` or commit message |
| Class names like `PlayerController` | Implementation detail | Use design names ("the Hero") |
| Exact balance numbers without rationale | Hard to revisit | Always pair with intent |
| Walls of prose | Unscannable | Tables and bullets |
| No version / date | Can't tell what's current | Top-of-file "Last updated: YYYY-MM-DD" |
| Confirmed mechanics without playtest | False certainty | Keep `[HYPOTHESIS]` tag until validated |

## Cross-references

After updating the GDD, check whether `PROGRESS.md` or `CLAUDE.md` need follow-up. The `update-docs` skill performs that cross-check.
