# Changelog

All notable changes to **godot-superpowers** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [1.12.3] — 2026-05-05

### Fixed
- **Plugin manifest: `skills` MUST be declared as an explicit array of paths.** v1.12.2 attempted to fix the zero-skill bug by removing the `skills` and `mcpServers` fields entirely, on the (incorrect) assumption that all four resource types (`skills/`, `agents/`, `hooks/hooks.json`, `.mcp.json`) were auto-discovered by Claude Code's plugin loader. Empirically false: `agents/`, `hooks/hooks.json`, and `.mcp.json` ARE auto-discovered (a fresh `/reload-plugins` reported `20 agents · 10 hooks · 5 plugin MCP servers`), but `skills/` is **not** — the loader requires `skills` to be an explicit array of individual skill paths in the manifest, matching the `andrej-karpathy-skills` pattern (`"skills": ["./skills/karpathy-guidelines"]`). v1.12.2 with the field omitted reproduced the same `0 skills` outcome as pre-v1.12.2 with the field as a string. v1.12.3 declares the field as a 33-entry array enumerating every `./skills/<name>` path explicitly.
- **Validator now enforces array-of-paths parity.** `scripts/validate.sh` adds a new `Plugin manifest skills array (loader registration parity)` check that (a) confirms `skills` is an array (not a string, not absent), (b) confirms its length equals the on-disk SKILL.md count, and (c) verifies 1:1 parity between every array entry and every `skills/<name>/` directory. This blocks both regressions: silent string fallback and adding a new skill directory without updating the manifest array.

### Why
- v1.12.2's reasoning was wrong by analogy: the working examples surveyed (`superpowers`, `vercel`, `ralph-loop`, `caveman`) were all plugins that ship **zero** custom skills (skills loaded via the global `superpowers` plugin or via none at all). They omit `skills` because they have nothing to declare, not because the field auto-discovers. The only surveyed plugin that actually ships skills (`andrej-karpathy-skills`) declared them as an explicit array — that was the correct signal, missed.
- The new validator check forces every future skill addition through a manifest update, eliminating the "33 directories on disk, 0 registered with loader" failure class entirely.

## [1.12.2] — 2026-05-05

### Fixed
- **Plugin manifest: skills + mcpServers fields removed (zero-skill bug).** `.claude-plugin/plugin.json` previously declared `"skills": "./skills/"` and `"mcpServers": "./.mcp.json"` as **strings**. The Claude Code plugin loader expects `skills` to be an **array of individual skill paths** (see `andrej-karpathy-skills`: `"skills": ["./skills/karpathy-guidelines"]`); a string value is silently dropped on load. Result: every install of v1.1.0 through v1.12.1 reported `Reloaded: 4 plugins · 0 skills` for godot-superpowers — the plugin appeared installed but registered zero skills, leaving end users with only what hooks/agents/MCP discovered separately. Fixed by removing both fields entirely and relying on auto-discovery (the same pattern `superpowers`, `vercel`, `ralph-loop`, and `caveman` use — none of those manifests carry `skills` or `mcpServers` fields). The `skills/` directory and `.mcp.json` are now picked up by convention.

### Why
- This is the most consequential bug the plugin has shipped: every "33 skills" claim in README / CLAUDE.md / marketplace description was technically correct on disk but functionally false at runtime, because the loader registered none of them. Anyone who installed pre-v1.12.2 saw the dispatcher and design gates not auto-loading on `.gd` / `.tscn` files (their `paths` glob never registered with the matcher), genre packs absent from `/skills`, and create-* skills unreachable. The plugin was effectively a 33-file documentation set rather than an active skill catalog.
- Detection failure: the validator (`scripts/validate.sh`) parsed `plugin.json` with `jq` (well-formed JSON), counted skill directories on disk (33 found), and reported PASS — it never simulated what the loader would actually register, so the schema mismatch went undetected for 12 minor versions.

## [1.12.1] — 2026-05-05

### Fixed
- **`godot-docs` MCP server: corrected npm package name.** `.mcp.json` previously launched `npx -y godot-docs-mcp`, but that package does not exist on the npm registry (404). The server therefore silently failed to start on every install, leaving the MCP unreachable despite appearing in the config. Fixed by switching to the canonical package: `@fernforestgames/mcp-server-godot-docs` (v0.1.1, MIT, by jspahrsummers).
- **`godot-docs` MCP server: documented `GODOT_PATH` requirement.** The corrected package extracts bundled XML class docs from a local Godot install and fails fast with `Error: GODOT_PATH environment variable must be set` when the env var is missing. `.mcp.json` now declares the env passthrough; `README.md` and `mcp-meta.json` document the required export with platform-specific paths (macOS/Linux/Windows). Without `GODOT_PATH`, the server starts but every tool call errors.

### Why
- Tier 1 MCP integrity: this is the server that every code-emitting skill cites for API verification ("Authoritative source" callout in the dispatcher). Shipping a non-existent package name meant the entire verify-API-before-emitting-code discipline was running on a server that wasn't actually live — Claude could not detect this from inside the session because MCP tool listing never errors on a non-starting server, it just shows zero tools.

## [1.12.0] — 2026-05-05

### Changed (breaking — workflow simplification)
- **Design gates are now soft-gates with explicit opt-out.** `game-brainstorming`, `writing-game-plan`, `feature-spec`, and `feature-plan` previously used `<HARD-GATE>` blocks that forbade implementation skills until both artifacts were written and approved. They now use `<SOFT-GATE>` blocks: default behavior is unchanged (propose the design pass, get approval), but the user can bypass per-session with `/skip-design` (or any clear equivalent). On opt-out, Claude warns ONCE about scope-creep / regression risk, gets a confirmation, then proceeds. The `orchestrator` agent applies the same soft-gate on dispatch — refuses unless the plan is approved OR the dispatching prompt carries an explicit waiver string (`design-gate: waived` / `/skip-design`). When waived, the orchestrator prepends a single warning line to the user-facing report.
- **`Authoritative source` callout consolidated into the dispatcher only.** Previously, the same blockquote was duplicated in 37 skill/agent files (the validator enforced both presence in code-emitting files and absence in design-only files). The rule now lives only in `using-godot-superpowers` (the auto-loaded dispatcher), which is in context on every Godot session via its `paths` glob. Validator now enforces dispatcher-only presence and rejects duplicates anywhere else. Net effect: ~37 redundant blockquotes removed across the catalog.
- **`file-verifier` is opt-in, not per-write.** The PostToolUse hook (`verifier-reminder.sh`) now accumulates Godot writes per project and emits the dispatch reminder only once a threshold is reached (default 3, override via `CLAUDE_VERIFIER_THRESHOLD`). Counter file lives under `$TMPDIR`. Single-file edits no longer trigger verifier dispatch. Decision rules in the dispatcher updated: dispatch verifier on milestone-sized batches (≥3 files) or single risky files; skip for trivial edits.
- **Hooks unified to one source of truth.** `settings.json` `.hooks` is now the only hand-edited hooks block. `hooks/hooks.json` is regenerated from it automatically by `scripts/validate.sh` at the top of every run, eliminating the drift class entirely. `scripts/sync-hooks.sh` is preserved for manual regeneration but the validator's parity check is replaced by deterministic auto-sync.

### Removed
- **`memory` MCP server (tier 2).** The orchestrator state was already canonically stored in the `<orchestrator-state>` block inside the active plan markdown — `memory` MCP was a duplicate source of truth. Removed from `.mcp.json`, `mcp-meta.json`, and the `settings.local.json.example` comment. Tier 2 now contains only `git`.

### Why
- Friction reduction. The previous hard-gate workflow required the user to clear two design documents (or three for feature-trail) before any code ran, which made the plugin hostile for jam-game prototyping and exploratory work. The soft-gate keeps the design-first default — it remains the recommended path — but admits that a user opting out explicitly is making an informed trade-off, not a mistake to be policed.
- Token economy. Duplicating the `Authoritative source` callout across 37 files cost roughly 40 lines × 37 = ~1500 lines of identical context that was already in scope via the auto-loaded dispatcher. The validator now actively prevents reintroduction.
- Verifier overhead. Dispatching `file-verifier` (Haiku) after every single-file write paid sub-agent overhead for cases where main-context Read + the existing `gdformat` / `gdlint` / `--check-only` hooks already covered the surface. The threshold model concentrates verifier dispatch on the cases where the cost actually returns value: milestone batches and risky single files.
- Source-of-truth duplication. Two places to maintain the hooks block (settings.json + hooks/hooks.json) was a bug factory; the validator's parity check caught drift but did not prevent it. Auto-sync makes drift impossible.

## [1.11.0] — 2026-05-05

### Added
- **Meshy MCP server bundled at tier 3** (`@meshy-ai/meshy-mcp-server`). Provides 3D model generation: text-to-3D, image-to-3D, multi-image-to-3D, retexture, remesh, rigging, animation. Used by the `art-director` agent for 3D-asset scaffolding. Server stanza ships in `.mcp.json` with `MESHY_API_KEY` declared as an environment passthrough — the user only has to export the key in their shell and append `"meshy"` to `enabledMcpjsonServers` in `settings.local.json` to opt in. Key obtainable at https://www.meshy.ai/api.

### Changed
- **README "MCP servers" section** now distinguishes two tier-3 sub-cases:
  - **Bundled, needs API key** (`meshy`) — stanza ships in `.mcp.json`, user supplies env var.
  - **External, BYO config** (`elevenlabs`, `pixellab`, `comfyui`) — stanza NOT shipped because the package/key/self-hosted backend varies per user.
- **`mcp-meta.json`** schema extended: each server entry may now carry an optional `credential` block (`env`, `required`, `where_to_get`) and a `note` field documenting bundling rationale. Added the corresponding entry for `meshy`.
- **`settings.local.json.example`** comment updated to mention the new tier-3 opt-in flow.

### Why
- The `art-director` agent previously had no first-party route to generate placeholder 3D meshes — projects that needed a 3D character or prop fell back to manual asset hunting or hand-modeling. Meshy AI's API covers the full text/image-to-3D + remesh + rig pipeline, and its MCP server has a canonical npm package, so bundling it is low-risk. Tier 3 is the right slot: it's optional, requires user-supplied credentials, and downstream skills must still gracefully degrade when the server is absent.

## [1.10.0] — 2026-05-05

### Added
- **`scripts/hooks/_lib.sh`** — shared helper sourced by every PostToolUse hook script. Provides `_hook_normalize_path` that rebases relative path entries from `CLAUDE_FILE_PATHS` onto `$CLAUDE_PROJECT_DIR` before any `[ -f ]` / `[ -d ]` test. Prevents silent skipped checks when the runtime cwd is not aligned with the project root. (audit Doc2 #1)
- **`scripts/validate.sh` `allowed-tools` enforcement** — every skill must now declare `allowed-tools` in frontmatter unless it is on the explicit `ALLOWED_TOOLS_EXEMPT` list (`using-godot-superpowers`, `subagent-dev-mode`, `game-brainstorming`). Validator FAILs on missing field for any other skill. Closes the documentation gap that let four foundation skills ship without the `allowed-tools` constraint that all other skills observed. (audit AUDIT.md #1)
- **`README.md` "Portability across clients" section** — lists which tool-name primitives map across Claude Code / Copilot CLI / Cursor / Codex, and is explicit that hooks + MCP wiring are Claude Code conventions and do not transfer 1:1. (audit Doc3 portability)

### Fixed
- **Hook scripts** (`scripts/hooks/dep-integrity.sh`, `verifier-reminder.sh`, `check-tscn.sh`, `gdformat-gd.sh`) now source `_lib.sh` and call `_hook_normalize_path` after the trim step, before the file-existence test. Closes the path-normalization gap from audit Doc2 #1.
- **`agents/game-designer.md` callout tension** — the agent carries the standard "Authoritative source" callout *and* says "don't write GDScript code or class names" further down. Added a follow-up blockquote that makes the resolution explicit: design docs cite Resource names, system concepts, and version claims, and *those* must remain API-accurate even when no code is emitted. The rule is "verify named-API claims," not "verify only when shipping code." (audit AUDIT.md #2)
- **`skills/subagent-dev-mode/SKILL.md` Researcher row** — `Explore` model column changed from hardcoded `sonnet` to `IDE default`. The host's default for the built-in `Explore` subagent can change between Claude Code releases; hardcoding a model name was a forward-compat hazard. (audit Doc4 2.2)
- **Caveman-mode references marked optional** in `skills/subagent-dev-mode/SKILL.md` (line 105) and `agents/orchestrator.md` (line 144) — the feature is provided by the external `superpowers` plugin and was previously cited without the dependency note. Drop-in users without that plugin would have read it as a documented behavior of this plugin. (audit Doc3 + Doc4 2.1)

### Changed
- **`scripts/validate.sh` count drift detection rewritten** — replaced indiscriminate `[0-9]+ skills` / `[0-9]+ subagents` regex (which matched any prose mention of those numbers) with `check_count_anchored` that targets only canonical positions: CLAUDE.md tree comments + `## Skill catalog (N)` / `## Agent catalog (N)` headers, README.md `### N skills` / `### N subagents` H3 headers, and the marketplace.json description prefix. Each anchor regex contains a single `(...)` capture group; bash `=~` + `BASH_REMATCH[1]` extracts the number. No more false positives from prose. (audit Doc3 validator)
- **`scripts/validate.sh` exempt-set DRY** — extracted the design-only-skill list (skills that never emit Godot 4.x API) into a single `DESIGN_ONLY_SKILLS` array used by both the callout-presence skip and the callout-absence enforcement loops. Adding a new design-only skill is now a one-line edit instead of two. Same refactor introduces a tiny `_in_array` helper. (audit Doc3 validator DRY)
- **`CHANGELOG.md` 1.6.0 / 1.7.0 / 1.8.0 backfilled** — three placeholder "undocumented maintenance" entries replaced with one consolidated `[1.6.0] – [1.8.0]` entry that lists the cumulative deltas (2 new agents, 4 new skills, hook script extraction, orchestrator integration step) reconstructed by diffing the v1.5.0 git tag against the v1.8.1 working tree. Per-version assignment is documented as unrecoverable from git. Going-forward rule: every version bump must land with a tagged commit and a dedicated changelog entry. (audit AUDIT.md #3)

### Why
- Audit pass identified medium / low residual issues: silent path-handling failure mode in hooks, fragile validator regex that could mask real drift, validator inconsistency around `allowed-tools` coverage, doc references to optional external features without dependency notes, hardcoded model name that drifts with the host, and three placeholder CHANGELOG entries that gave no context for any regression that traced to that range. None individually critical; together they degraded the plugin's self-describability and resilience to upstream changes. This release is corrective + tooling — no new skills, no new agents.

## [1.9.0] — 2026-05-05

### Fixed
- **Glob-unsafe path splitting** in `scripts/hooks/dep-integrity.sh` and `scripts/hooks/verifier-reminder.sh` — replaced with `IFS=',' read -ra paths <<< "$paths_raw"` matching the pattern in `gdformat-gd.sh` and `check-tscn.sh`. (audit A)
- **`scripts/validate.sh` agent callout loop** contained a dead `case … esac` block; replaced with an explanatory comment. (audit C)
- **`skills/setup-save-system/SKILL.md`** — `play_time_seconds` no longer resets to engine boot every save; now accumulates across sessions via `_play_time_accum` + `_session_start_msec`. (audit Doc4 2.1)
- **`skills/setup-save-system/SKILL.md`** — replaced `change_scene_to_file()` with `change_scene_to_packed()` per project rule, using `load() as PackedScene` for dynamic save paths. (audit Doc4 2.2)
- **`skills/create-scene/SKILL.md`** — replaced ambiguous `Area`, `NavigationRegion (2D or 3D)`, `Marker (2D or 3D)`, `StaticBody`, etc. with dimension-explicit Godot 4.x classes (`Area2D`/`Area3D`, `NavigationRegion2D`/`NavigationRegion3D`, …). Split combined enemy/level templates into 2D and 3D variants. (audit Doc4 2.4)
- **`skills/genre-pack-3d-action/SKILL.md`** — `lock_on` action handler moved from `_input` to `_unhandled_input` so UI captures take precedence. (audit Doc4 2.3)
- **`agents/orchestrator.md`** step 8 now dispatches `milestone-integrator` instead of self-editing the plan; the integrator owns the milestone Status flip. `agents/milestone-integrator.md` and `skills/subagent-dev-mode/SKILL.md` updated to match. (audit K — main correctness fix)
- **`skills/feature-spec/SKILL.md`** cross-cutting refactor escalation now points to Trail A (re-brainstorm + GDD + plan), not just `writing-game-plan`, matching the dispatcher. (audit Doc4 1.2)
- **`skills/using-godot-superpowers/SKILL.md`** Trail B section now documents the trivial-feature shortcut (1 file + no new mechanic + no new public surface → marker `Survey reference: none (trivial shortcut)`). (audit Doc4 1.4)
- **`skills/game-brainstorming/SKILL.md`** description no longer claims to produce the implementation plan (handed off to `writing-game-plan`); removed misplaced `allowed-tools` frontmatter; HARD-GATE list extended with `save-schema-migration`, `ui-patterns-godot`, `networking-foundation`, `setup-git-godot`, plus a "when in doubt, gate" catch-all. (audit D + E + Doc4 1.3)
- **`scripts/hooks/pre-bash-guard.sh`** regex tightened — allows legit `git checkout <branch>` / `git checkout -b` / `git restore --staged`; still blocks discard forms, `--force`, `--hard`, `branch -D`, `clean -*f*`, `reflog expire --expire=now`, `gc --prune=now`. New `CLAUDE_GIT_OVERRIDE=1` env bypass for git rules (destructive shell pattern check NEVER bypassed). (audit L)
- **`scripts/hooks/check-tscn.sh` and `scripts/hooks/gdformat-gd.sh`** now print a one-line "skipped (tool not on PATH...)" notice instead of exiting silently. (audit P)

### Changed
- **`CLAUDE.md`** exempt-set listing extended with `setup-git-godot` and `export-config` to match `scripts/validate.sh:139`. (audit B)
- **`CLAUDE.md` and `README.md`** moved `subagent-dev-mode` out of "Design gates" into a new "Execution / Orchestration" subsection — it never was a design gate. (audit G)
- **`CLAUDE.md`** gained a "Hook environment variables" reference subsection (`CLAUDE_FILE_PATHS`, `CLAUDE_PROJECT_DIR`, `CLAUDE_COMMAND`, `CLAUDE_AGENT_NAME`, `CLAUDE_SUBAGENT`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_GIT_OVERRIDE`) and two design notes (4-hook PostToolUse spawn overhead by design; stop-gdlint coverage limited to `scripts/`+`autoload/` by design). (audit O + H + I)
- **`.claude-plugin/mcp-meta.json`** gained a top-level `pinning_policy` block (`floating`, rationale, quarterly review). `README.md` MCP section documents it. (audit N)

### Why
- Follow-up to the AUDIT.md / audit-sistema-godot-superpowers-2026-05-05 / ANALISI-SISTEMA / Analisi_Sistema_Godot_Superpowers reports. Resolves a logical contradiction between orchestrator and milestone-integrator (audit K — the only point with real correctness impact), eliminates a glob-expansion bug in two hook scripts, fixes two GDScript snippet bugs in `setup-save-system`, and aligns documentation with what the validator actually enforces. No new skills or agents.

## [1.8.1] — 2026-05-05

### Fixed
- **Drop-in install command in `README.md`**: now includes `scripts/`, matching the `CLAUDE.md` Distribution section. Without it, every hook in `settings.json` (which resolves helpers at `${CLAUDE_PLUGIN_ROOT:-$CLAUDE_PROJECT_DIR/.claude}/scripts/hooks/*.sh`) silently failed in drop-in mode.
- **`scripts/hooks/check-tscn.sh` truncation bug**: the script piped `godot --headless --check-only` output through `head -5`, but Godot prints its Vulkan/audio init banner in the first ~5 lines, so real "Corrupt scene" errors past line 5 were hidden. Now checks the exit code and surfaces error-bearing lines (filtered with grep) when the check fails.
- **`scripts/hooks/gdformat-gd.sh` and `check-tscn.sh` glob-unsafe path parsing**: `IFS=','; paths=( $paths_raw )` triggered filename expansion on path entries containing wildcards. Replaced with `IFS=',' read -ra paths <<< "$paths_raw"` (glob-safe).
- **`gdformat-gd.sh` per-file process spawn**: now batches all `.gd` paths into one `gdformat` call (gdformat accepts multiple args), with a per-file fallback only when the batch run fails.
- **`scripts/hooks/stop-gdlint.sh` silent truncation**: `gdlint` output was piped through `head -10` with no indication when more errors existed. Now prints a footer like `... (showing first 10 lines; N more — run 'gdlint <dir>' to see all)` when truncation hit.
- **`scripts/hooks/pre-bash-guard.sh` regex coverage**: the destructive-git rule blocked dot-targets (`git checkout .`, `git restore .`) but not path-specific forms (`git checkout -- file.gd`, `git restore file.gd`), which also discard uncommitted work. Extended the regex to cover both.
- **`save-schema-migration` skill assertion**: the migration loop's invariant assertion was a complex filter expression that did not actually guarantee `schema_version` advances by exactly one per pass. Replaced with a strict `assert(data.schema_version == previous + 1, ...)` check.
- **`ui-patterns-godot` skill** mislabeled `AspectRatioContainer` as `4.3+`; the class is available in earlier Godot 4.x and predates 4.3. Removed the version qualifier.
- **`using-godot-superpowers` dispatcher** Trail A wording: frontmatter and body now agree on the canonical sequence. Gate-list bullet now explicitly notes that `networking-foundation`, `ui-patterns-godot`, `setup-git-godot`, and `save-schema-migration` are also implementation-grade skills covered by the gate.
- **Test directory convention**: skills referenced both `test/` and `tests/`. Standardized on `test/` (matches GUT's `gut_cmdln.gd` default `-gdir=res://test/...`); `feature-plan`, `codebase-survey`, and `update-docs` updated.
- **`milestone-integrator` smoke test**: the agent's smoke command was `godot --headless --check-only --path ... <main_scene>`, but `--check-only` is documented for GDScript parsing, not scene loading. Replaced with `godot --headless --path ... --quit-after 1 <main_scene>` (boots the engine for one frame and exits), which actually invokes `_ready()` on root nodes.
- **`scripts/validate.sh` callout exempt list**: `setup-git-godot` and `export-config` never emit Godot 4.x API code (they emit `.gitignore`, `.gitattributes`, bash, `.cfg`, GHA YAML). Added them to both the presence-check skip list and the absence-check enforcement list. The redundant "Authoritative source" blockquote was removed from both skills.

### Why
- Audit identified a cluster of small drift / fragility issues across hooks, docs, and skills. None individually critical; together they degraded reliability of drop-in mode, error visibility, and skill self-consistency. This release is purely corrective — no new skills or agents.

## [1.6.0] – [1.8.0] — 2026-05-05 (reconstructed retroactively)

> **Backfill note**: versions `1.6.0`, `1.7.0`, and `1.8.0` shipped between `1.5.0` and `1.8.1` (all on 2026-05-05) without per-version git commits or per-version changelog entries. The cumulative deltas across the three bumps are recorded here, reconstructed by diffing the v1.5.0 tag against the v1.8.1 working tree. Per-version assignment is not recoverable from git history. Going forward, every version bump MUST land with a tagged commit and a dedicated changelog entry.

### Added
- **`agents/merge-specialist.md`** — repairs `.tscn` / `.tres` after bad merges or refactors (conflict markers, broken `id=` references, UID drift).
- **`agents/milestone-integrator.md`** — post-batch integration gate dispatched by `orchestrator`. Aggregates verifier verdicts + test outcomes, runs headless smoke (`godot --headless --quit-after 1`), owns the plan Status flip.
- **`skills/networking-foundation/SKILL.md`** — Godot 4.x High-Level Multiplayer foundation: `ENetMultiplayerPeer` setup, `MultiplayerSpawner` / `MultiplayerSynchronizer` patterns, `@rpc` annotations + authority model, server-vs-client-authoritative tradeoffs.
- **`skills/save-schema-migration/SKILL.md`** — versioned save data with sequential `v1→v2→v3` migration registry, fallback for unknown versions, fixture-based regression tests.
- **`skills/setup-git-godot/SKILL.md`** — `.gitignore` for engine cache + exports, `.gitattributes` with Git LFS for binary assets (PNG/WAV/OGG/FBX/GLB/BLEND/ZIP), `.gdignore` for asset-only folders, one-time LFS init.
- **`skills/ui-patterns-godot/SKILL.md`** — Theme + StyleBox setup, Control focus chain, `_unhandled_input` vs `_gui_input`, anchors + containers, `stretch_mode` + `content_scale_size` for responsive UI, CanvasLayer for HUD, accessibility floor.
- **Hook scripts extracted to `scripts/hooks/`** — `gdformat-gd.sh`, `check-tscn.sh`, `dep-integrity.sh`, `verifier-reminder.sh`, `pre-bash-guard.sh`, `session-start.sh`, `stop-gdlint.sh`. Previously inline shell strings inside `settings.json` `hooks` block; extraction enables per-script review, sourcing shared helpers, and bash linting.
- **`agents/orchestrator.md` integration step** — orchestrator now dispatches `milestone-integrator` via the `Agent` tool after the worker batch completes, instead of flipping the plan Status itself.

### Changed
- **Skill catalog count**: 29 → 33 (the four foundation skills above).
- **Agent catalog count**: 13 → 15 (the two agents above).
- **`scripts/validate.sh`** extended to cover the new hook scripts (parity with `settings.json`) and the new agents.

## [1.7.0] — superseded
Folded into the consolidated `[1.6.0] – [1.8.0]` entry above.

## [1.6.0] — superseded
Folded into the consolidated `[1.6.0] – [1.8.0]` entry above.

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
