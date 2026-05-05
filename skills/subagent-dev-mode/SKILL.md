---
name: subagent-dev-mode
description: "Activate subagentic development mode for milestone execution: an orchestrator agent decomposes work into parallel workers, each write is verified externally by file-verifier, and main-context tokens are kept minimal. Use when the user asks to implement a milestone, build a multi-file feature, or says 'subagent mode' / 'orchestrator mode'."
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Subagent dev mode

A workflow that turns Claude into a thin coordinator: real work happens in subagents with isolated context. Main context stays small; correctness is double-checked by an external verifier.

## When to use

Use subagent dev mode when **all** of the following are true:

1. The matching design trail has cleared. Either:
   - **Trail A (greenfield)**: approved GDD (`game-brainstorming` + `gdd-writer`) AND approved plan (`writing-game-plan`).
   - **Trail B (feature on existing game)**: approved feature spec (`feature-spec`, optionally informed by `codebase-survey`) AND approved feature plan (`feature-plan`).
2. The current task is implementing a milestone or a feature touching **3+ files** or **2+ subsystems**.
3. The user has not asked for a quick one-shot fix.

Do NOT use subagent dev mode for:

- Single-file edits (call the skill directly — dispatch overhead is not worth it).
- Brainstorming / planning (those run in main context).
- Read-only investigations (`Explore` subagent or direct `Grep`).
- Bug fixes with a known root cause (direct edit + `code-reviewer`).

## Activation triggers

Activate this mode when the user says (or implies):

- "Implement milestone M2"
- "Build the player + health + hurtbox feature"
- "Roll out the localization system"
- "Subagent mode" / "orchestrator mode"
- "Parallelize this" / "split this work"

## Roles

| Role | Agent | Model | Reads | Writes |
|---|---|---|---|---|
| **Orchestrator** | `orchestrator` | sonnet | plan, GDD, file paths | `<orchestrator-state>` block + plan status |
| **Worker** | one of the implementation skills/agents | sonnet | files in its scope | the file it owns |
| **Verifier** | `file-verifier` | haiku | one file + `project.godot` | nothing — findings only |
| **Integrator** | `milestone-integrator` | sonnet | plan, verifier verdicts, test outcomes; runs headless smoke | plan markdown status flip only |
| **Researcher** | `Explore` (built-in) | IDE default | codebase | nothing |

Main-context Claude becomes a thin shell: it confirms preconditions, hands the milestone to the orchestrator, relays the orchestrator's report to the user, and asks the next question.

## Operating loop

```
user picks milestone
  │
  ▼
main-context Claude checks preconditions  (GDD ✓, plan ✓, milestone named)
  │
  ▼
dispatch orchestrator (Agent: orchestrator)
  │
  ▼
orchestrator decomposes into N independent worker tasks
  │
  ▼
orchestrator dispatches workers IN PARALLEL  (single message, N Agent calls)
  │
  ▼
each worker writes its file(s), reports ≤200 words
  │
  ▼
orchestrator dispatches file-verifier on each written file  (parallel where possible)
  │
  ▼
verifier returns findings (no rewrite)
  │
  ▼
if any CRITICAL → orchestrator dispatches fix-worker, re-verifies
  │
  ▼
orchestrator dispatches milestone-integrator (smoke test + status flip)
see agents/milestone-integrator.md — runs `godot --headless --quit-after 1`
(with `--check-only` fallback), checks acceptance criteria, owns the
milestone Status flip in the plan markdown
  │
  ▼
orchestrator reports batch summary to main-context Claude (includes integrator verdict)
  │
  ▼
main-context Claude relays summary, awaits "next phase" / "next milestone"
```

## Token discipline (the why)

Main context grows whenever Claude reads a file or holds a long tool result. Subagent dev mode keeps main context flat:

| Tactic | Effect |
|---|---|
| Workers run in **isolated context** (subagent property) | Worker output is one summary, not full file diff |
| Verifier reads file **fresh**, returns findings only | Main context never ingests the full file |
| Orchestrator never re-reads files workers wrote | No duplicate file reads |
| Plan persists in the active plan markdown (trail A: `docs/plans/<YYYY-MM-DD>-<slug>-plan.md`; trail B: `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md`), not chat scrollback | Resume across sessions without re-reading history |
| Parallel dispatch (1 message, N Agent calls) | Same wall-time as one worker; no sequential context bloat |
| `Explore` subagent for codebase research | Read-only, isolated, returns excerpts |
| Caveman mode for inter-agent prose (optional — requires the `superpowers` plugin; harmless if absent) | Less filler in summaries |

**Rule of thumb**: main-context Claude should read no game source files in subagent dev mode. Only plan, GDD, and orchestrator reports.

## Step-by-step (what main-context Claude does)

1. **Confirm preconditions** (one trail must be fully cleared):
   - **Trail A — greenfield**:
     - `docs/design/<YYYY-MM-DD>-<slug>-gdd.md` exists and is approved.
     - `docs/plans/<YYYY-MM-DD>-<slug>-plan.md` exists and is approved.
   - **Trail B — feature on existing game**:
     - `docs/features/<YYYY-MM-DD>-<slug>-feature.md` exists and is approved.
     - `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md` exists and is approved.
   - User named a milestone or feature scope (e.g. "M2: vertical slice", or "implement the dash feature").
   If any missing, route back to the matching skill: `game-brainstorming` / `writing-game-plan` for trail A, or `codebase-survey` / `feature-spec` / `feature-plan` for trail B. Do not proceed.

2. **Hand off to orchestrator**:
   ```
   Use the orchestrator agent. Brief:
     - Plan path: docs/plans/<YYYY-MM-DD>-<slug>-plan.md
     - Milestone to execute: <name>
     - Constraints: <any tunables the user just specified>
     - Report format: batch summary per orchestrator skill spec
   ```
   Use the `Agent` tool with `subagent_type: "orchestrator"`.

3. **Relay the report**. The orchestrator returns a structured summary (files touched, verifier verdicts, deviations, open questions). Print it to the user verbatim or condensed; do not re-explain what the orchestrator already explained.

4. **Confirm next step**. Ask the user: continue to next phase / fix flagged items / pause. Do not advance autonomously past a milestone boundary.

## When something goes wrong

| Symptom | Action |
|---|---|
| Verifier flags CRITICAL on a worker file | Orchestrator auto-dispatches a fix-worker; if it loops twice, escalate to user with the verifier's exact findings |
| Worker reports "could not find file X" | Orchestrator dispatches `Explore` to locate; if missing entirely, escalate |
| Worker deviates from plan | Orchestrator captures deviation in batch summary; main-context Claude asks user to approve / reject |
| `godot-docs` MCP unavailable | Workers and verifier fall back to `https://docs.godotengine.org/en/stable/` and **say so** in their reports — main-context Claude warns the user |
| User wants to pause mid-milestone | Orchestrator updates the active plan file (trail A: `docs/plans/<YYYY-MM-DD>-<slug>-plan.md`; trail B: `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md`) with current state and stops; resume reads the same file |

## Anti-patterns

- ❌ Main-context Claude reads a `.gd` or `.tscn` file "to check what the worker did". The verifier already did. Trust it.
- ❌ Orchestrator writes code. It dispatches.
- ❌ Verifier rewrites code. It returns findings only.
- ❌ Sequential dispatch when tasks are independent. Parallelize.
- ❌ Skipping the verifier on a small file. Small files have just as many API drift bugs as big ones.

## Interaction with hooks

The `gdformat` and `godot --check-only` hooks still run on every write — they catch syntactic issues. The verifier handles semantic issues (API correctness, conventions, plan alignment). The hook also prints a one-line reminder when subagent dev mode is implied but verifier was not invoked. Don't ignore it.

## Cost note

The verifier uses Haiku (cheap), the orchestrator uses Sonnet (mid), workers use whatever model the invoked skill/agent declares. Parallel dispatch raises peak-concurrent cost briefly but lowers total cost vs. a single sequential agent that has to keep all context loaded. For a 5-file milestone the typical cost ratio vs. monolithic execution is roughly 0.6–0.8x with much higher correctness.
