# Changelog

All notable changes to **godot-superpowers** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

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
