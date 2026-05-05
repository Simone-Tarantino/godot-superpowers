# Changelog

All notable changes to **godot-superpowers** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [1.5.0] — 2026-05-05

### Added
- **Feature-mode trail (trail B)** for changes on top of an existing game, parallel to the existing greenfield trail (`game-brainstorming` → `gdd-writer` → `writing-game-plan`). Three new design-gate skills, gated by user approval, hard-block implementation skills until approved:
  - **`codebase-survey`** — read-only mapping of scenes / scripts / autoloads / resources / signals a planned feature will touch. Output: `docs/features/<YYYY-MM-DD>-<slug>-survey.md`. Captures public API, integration points (signal subscribers, callers), regression hotspots (3+ refs), and `[OPEN]` questions for the spec.
  - **`feature-spec`** — surgical design doc for one bounded feature. Output: `docs/features/<YYYY-MM-DD>-<slug>-feature.md`. Sections: Problem / Player-facing change / Scope IN / Scope OUT / Integration / New mechanics (`[HYPOTHESIS]` template reused from `gdd-writer`) / Regression risks / Acceptance criteria / Tuning numbers / Rollback plan / Open questions. Includes a trivial-feature shortcut (one-file changes can skip survey + most sections).
  - **`feature-plan`** — milestone-based technical plan from spec + survey. Output: `docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md`. Required tables: Files create / Files edit / Files delete; mandatory regression-test plan tied to survey hotspots; `<orchestrator-state>` placeholder. Sequencing rules require regression tests against current behavior BEFORE feature integration.
- **Orchestrator now accepts either trail.** `agents/orchestrator.md` "Hard preconditions" section restated as Path A (greenfield: GDD + plan) OR Path B (feature: spec + feature-plan). Decomposition heuristics gain feature-mode rows. The `<orchestrator-state>` block path now resolves to the active plan file (whole-game `-plan.md` or feature `-feature-plan.md`).
- **Validator path-convention check**: `scripts/validate.sh` now verifies that each feature-trail skill body cites its canonical output path verbatim — drift between skill body and convention fails the build.
- **Validator skip list extended**: `codebase-survey`, `feature-spec`, and `feature-plan` are exempt from the "Authoritative source" callout requirement (design-only skills, never emit Godot code), consistent with `game-brainstorming` / `writing-game-plan` / `gdd-writer` / `update-docs` / `using-godot-superpowers`.

### Changed
- **`using-godot-superpowers` dispatcher** now routes design requests across two named trails (A — greenfield, B — feature on existing game) with explicit trigger-phrase tables and an updated "Order of operations" diagram. The auto-loaded `paths` glob list adds `*-feature.md`, `*-feature-plan.md`, `*-survey.md`.
- **`update-docs` cross-check** extended to the feature artefact set: surveys, specs, and feature plans are now part of the read-baseline; cross-checks include "Files: edit" path existence, acceptance-criterion ↔ PROGRESS coverage, regression-test presence per hotspot, and promotion of confirmed `[HYPOTHESIS]` mechanics from spec into the GDD.
- **README catalog and `CLAUDE.md` Skill catalog** updated from 26 → 29 skills. The three new skills sit under "Design gates" alongside the existing greenfield gates, with the trail (A vs B) labelled per skill.
- **`marketplace.json` plugin description** mentions the new feature-mode trail in addition to subagent dev mode.

### Why
- **Bounded changes need a bounded design surface.** Forcing a full GDD + whole-game plan for "add a double jump" creates friction so high that users skip the design gate entirely and bypass `file-verifier` discipline. The feature trail keeps the gate in place but scopes the artefacts to the actual delta.
- **Existing-game features fail because of integration, not invention.** Most rework comes from a new mechanic colliding with an existing signal subscriber or autoload contract. The mandatory survey step makes that integration surface explicit before the spec commits to a solution.
- **Orchestrator resumability across paths.** With the same `<YYYY-MM-DD>-<slug>` prefix used by survey, spec, and feature-plan (matching the greenfield prefix used by GDD + plan), the orchestrator state block remains a single deterministic resume point regardless of which trail produced the plan.
- **Test discipline before integration.** Writing a regression test against current behavior FIRST captures pre-feature truth — flipping the order would let the new behavior re-baseline the assertion silently, defeating the test.

## [1.4.0] — 2026-05-05

### Added
- **Unified GDD / plan file convention**: every GDD lives at `docs/design/<YYYY-MM-DD>-<slug>-gdd.md`, every plan at `docs/plans/<YYYY-MM-DD>-<slug>-plan.md`. `gdd-writer`, `update-docs`, `writing-game-plan`, `game-brainstorming`, `game-designer`, `orchestrator`, and `subagent-dev-mode` now all reference the same paths — no more `GDD.md` at root or `docs/<game>-*.md` ambiguity.
- **`settings.local.json.example`**: tracked install template for the per-user MCP enable file. Drop-in instructions copy it to `.claude/settings.local.json`. The actual `settings.local.json` stays gitignored.
- **`.claude-plugin/mcp-meta.json`**: sidecar describing tier + purpose per MCP server. Keeps `.mcp.json` strict to the MCP schema (no `_tier` / `_purpose` / `_comment` keys inline) so a stricter loader cannot reject the config.
- **Plugin / marketplace version coherence check** in `scripts/validate.sh`: refuses to PASS if `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` drift apart.
- **Tier-3 MCP availability callout** on `art-director` and `sound-designer` agents: pixellab / comfyui / elevenlabs are explicitly NOT bundled in `.mcp.json`, agents detect availability at runtime, fall back to placeholders + free CC0 sources, and say so in their report.

### Changed
- **`art-director` semantics aligned across dispatcher, agent, README, CLAUDE.md**: every surface now describes the agent as asset *generation* (PixelLab / ComfyUI MCP when available, placeholders + free CC0 otherwise). The dispatcher previously labelled it "planning-only", which contradicted the agent body.
- **`MoveComponent` in `create-component` is now genre-agnostic**: gravity, jump shaping, coyote / buffer windows, wall jump, and dash were leaking from `genre-pack-platformer` into the foundation skill. `create-component` ships only the generic 2D mover; platformer feel lives exclusively in `genre-pack-platformer` (`PlatformerMoveComponent`). A new "Genre specializations" table points readers to the matching pack.
- **README catalog re-aligned with skill frontmatter**: `setup-collision-layers` now mentions the 11-layer scheme; `create-scene` lists every template (player, enemy, level, main menu, pause menu, HUD, inventory, dialogue); genre packs include wall jump / dash / twin-stick aim / dodge roll / animation tree / deterministic RNG.
- **README "Conventions enforced"** added the missing rules already present in `CLAUDE.md`: `Parallax2D` (4.3+) over `ParallaxBackground` / `ParallaxLayer`, Resource save (not JSON), `_unhandled_input` over `_input`.
- **`.tscn` validation hook wording** in README + CLAUDE.md now matches the actual command: `godot --headless --check-only --path "$CLAUDE_PROJECT_DIR" <file>` (only the first 5 lines of output are surfaced).
- **`settings.local.json.example` MCP-enable semantics**: dropped `enableAllProjectMcpServers: true` to remove the ambiguity of pairing a "enable everything" flag with a partial whitelist. The file now uses an explicit `enabledMcpjsonServers` whitelist of tier-1 servers; tier-2 (`git`, `memory`) is opt-in.
- **`plugin.json` author** is now `Simone Tarantino` (with URL), matching `marketplace.json` `owner` and `plugins[0].author`. Previously listed as `godot-superpowers contributors`, which contradicted the marketplace metadata.
- **CI**: removed the redundant inline "Verify hooks parity" step from `.github/workflows/validate.yml`. `scripts/validate.sh` already runs the parity check; CI now invokes the validator only.
- **`scripts/validate.sh` JSON validity**: now covers `.claude-plugin/marketplace.json`, `.claude-plugin/mcp-meta.json`, and `settings.local.json.example` (required); `settings.local.json` is treated as optional with a clear `SKIP` line so a fresh clone (where the file is gitignored) does not fail validation.
- **`scripts/sync-hooks.sh`** comment clarified: plugin-mode reads `hooks/hooks.json` by Claude Code convention, not because `plugin.json` declares it.

### Fixed
- `marketplace.json` plugin description referenced the obsolete "verifier reminder" wording — replaced with "file-verifier dispatch reminder", consistent with the live hook output and the validator's own anti-drift check.
- `CLAUDE.md` Layout section now accurately documents what `plugin.json` actually declares (`skills` + `mcpServers` only) versus what is auto-discovered by Claude Code's plugin-mode convention (`agents/`, `hooks/hooks.json`).
- `subagent-dev-mode` skill: removed Italian phrase `'modalità subagentica'` from `description` and the trigger list. Repository content is English-only per `CLAUDE.md` policy; localized phrasings belong in language packs.

### Security
- `PreToolUse Bash` hook tightened: in addition to the existing destructive shell patterns (`rm -rf /`, `sudo rm`, `:(){ :|:& };:`, `mkfs`, etc.), the hook now blocks destructive git commands without explicit user confirmation: `git reset --hard`, `git clean -f*`, `git checkout .`, `git checkout -- .`, `git restore .`, `git push --force` / `git push -f`, `git branch -D`, `git reflog expire --expire=now`, `git gc --prune=now`. Settings allowed `Bash(git *)` blanket, which left these history-rewriting / working-tree-destroying commands unfiltered.

### Why
- **One source of truth for design artifacts**: with three competing path conventions, plans were sometimes written under `docs/<game>-plan.md` and read from `docs/plans/...`, breaking resume scenarios. Unified path makes the orchestrator's `<orchestrator-state>` block resumable across sessions.
- **Onboarding under a fresh clone**: `settings.local.json` is gitignored, so the README's `cp ... settings.local.json ...` command was broken on day 1. The tracked `.example` template plus updated copy instructions resolve it.
- **Schema stability for `.mcp.json`**: stripping `_*` annotations keeps the config compatible with strict-mode loaders without losing the human-readable tier metadata, which now lives in the sidecar.
- **Foundation skills must stay genre-agnostic** (per the existing `CLAUDE.md` editing rule). The platformer logic in `create-component` was a regression of that rule.
- **Destructive git is the most common irreversible action** Claude can take with `Bash(git *)` allowed. Adding it to the deny regex matches the same threat-model as the existing shell-destructive patterns.

## [1.3.1] — 2026-05-05

### Fixed
- `orchestrator` agent: dropped `TodoWrite` from declared tools (not portable across Claude Code versions); added `Edit` and `Write`. The orchestrator now updates the plan markdown directly instead of dispatching a worker for every checkbox flip.
- `orchestrator` agent: added a hard retry cap — maximum 2 fix-passes per file after a CRITICAL verifier finding, then escalate to the user. Prevents infinite verify→fix loops.
- `file-verifier` agent: explicit MCP-down downgrade rule. When `godot-docs` MCP is unavailable, every API-correctness finding drops from CRITICAL to WARNING; only syntactic Godot 3.x leftovers and missing type hints stay CRITICAL.
- Verifier-reminder hook: skips when running inside a subagent (`CLAUDE_AGENT_NAME` set), and produces one consolidated line for all changed files instead of one line per file. New output format: `verifier: dispatch file-verifier on <N> file(s) [<paths>]` (1.3.0 said `verifier reminder: dispatch file-verifier agent on <path>` per file). Less visual noise when the orchestrator is already auto-dispatching the verifier.
- `.mcp.json`: added `git` and `memory` servers at tier 2, matching the README. The `memory` server is recommended for the orchestrator to persist milestone state across sessions.

### Added
- `orchestrator` agent: canonical `<orchestrator-state>` block schema (milestone, phase, pending/in_progress/completed paths, blocked_on, fix_passes, last_updated). Lives at the top of the plan markdown; orchestrator reads it on resume instead of re-deriving state from chat history.
- `orchestrator` agent: language directive — final batch report to the user must match the user's chat language; file paths, severity tags, and code stay verbatim. Repository content stays English-only.
- GitHub Actions CI: `.github/workflows/validate.yml` runs `scripts/validate.sh` plus a hook-parity check on every push and PR to `main`.

### Why
- **Wasteful dispatch**: dispatching a full subagent just to flip a checkbox in a markdown file was costing tokens for no semantic check. Orchestrator now writes plan state directly.
- **Loop safety**: a verifier that keeps flagging CRITICAL on a file the writer cannot fix would have looped forever. Capped at 2 passes.
- **MCP availability is not guaranteed**: every claim of API correctness depended on `godot-docs` MCP. Without it, downgrade — do not guess.
- **Multilingual UX**: repository must stay English-only (per `CLAUDE.md`), but the user is not always English-speaking; orchestrator reports now match the user's chat language.

## [1.3.0] — 2026-05-04

### Added
- `orchestrator` agent (sonnet): decomposes a milestone into independent worker tasks, dispatches workers + `file-verifier` in parallel, aggregates short summaries. Never writes code itself. Hard-requires an approved GDD + plan + named milestone before running.
- `file-verifier` agent (haiku): external semantic check on a single Godot file after every Edit/Write. Reads the file fresh (no writer-context pollution), queries `godot-docs` MCP, returns CRITICAL/WARNING/INFO findings. Does not rewrite.
- `subagent-dev-mode` skill: documents the orchestrator + worker + verifier loop, activation triggers, token-discipline tactics, anti-patterns. Gated on approved GDD + plan.
- New `PostToolUse Edit|Write` hook: prints `verifier reminder: dispatch file-verifier agent on <path>` after any write to `.gd` / `.tscn` / `.tres` / `.gdshader`. Visible reminder so the verifier is not skipped.
- New verification rule in `using-godot-superpowers`: every write to a Godot source file must be followed by a `file-verifier` dispatch. Applies whether or not subagent dev mode is active.

### Changed
- README and CLAUDE.md catalogs: 26 skills (was 25), 13 subagents (was 11). Hook table updated.
- Marketplace and plugin descriptions reference the new subagent dev mode.

### Why
- Token discipline: workers and verifier run in isolated context, main-context Claude only ingests short summaries — milestones with 5+ files no longer balloon the main context.
- Correctness: every written file is independently re-read and checked against the live Godot 4.x docs MCP before being considered done. Catches API drift the writer's pre-trained knowledge would miss.

## [1.2.0] — 2026-05-04

### Added
- "Authoritative source" callout at the top of every skill (24) and every agent (11), instructing Claude / contributors to verify Godot 4.x APIs against the `godot-docs` MCP server before emitting code or examples. The dispatcher (`using-godot-superpowers`) carries the full rule with rationale.
- New CLAUDE.md editing rule documenting the callout convention so the rule is enforced in future skills.

### Why
- Pre-trained model knowledge of Godot drifts version by version (renamed methods, flipped argument orders, deprecated nodes). Pinning every skill to the live `godot-docs` MCP keeps generated code aligned with the user's installed Godot.

## [1.1.0] — 2026-05-04

### Added
- `using-godot-superpowers` skill: auto-loaded dispatcher (matches `**/*.gd`, `**/*.tscn`, `**/*.tres`, `**/*.gdshader`, `project.godot`, GDD/plan files) that enforces design-before-code on every Godot session.
- `game-brainstorming` skill: turns a game idea into an approved GDD through one-question-at-a-time dialogue tailored to game development (genre, scope, core loop, pillars, art / audio direction). Hard-gates all implementation skills until both GDD and plan are approved.
- `writing-game-plan` skill: approved GDD → milestone-based implementation plan that maps every step to a godot-superpowers skill, enforces sequencing rules (foundation first, vertical slice at M2, tests track features), and gates implementation behind explicit user plan approval.

### Changed
- README and CLAUDE.md catalogs now list 25 skills (was 22), with a new "Design gates" category.

## [1.0.1] — 2026-05-04

### Fixed
- Plugin manifest: dropped unsupported `agents` field (auto-discovered) and `hooks` reference (`hooks/hooks.json` is auto-loaded by convention).
- `hooks/hooks.json`: wrapped contents in the required `{"hooks": {...}}` envelope.

## [1.0.0] — 2026-05-04

Initial release.

### Added
- Plugin manifest (`.claude-plugin/plugin.json`) linking skills, agents, hooks, and MCP servers.
- 22 skills across foundation, scaffolding, quality, content, build, and four genre packs (platformer, top-down, 3D action, turn-based).
- 11 subagents covering review, scene architecture, design, QA, audio, art, performance, export, addons, migration, and playtest analysis.
- Hooks: `gdformat` on `.gd` write, `godot --check-only` on `.tscn` write, `gdlint` on stop, destructive Bash blocker, Godot version check on session start.
- Recommended MCP servers (`godot-mcp`, `godot-docs`, `context7`).
- Repo tooling: `scripts/sync-hooks.sh` (mirrors `settings.json` hooks → `hooks/hooks.json`) and `scripts/validate.sh` (JSON, hook parity, frontmatter, broken links).
- MIT license.
