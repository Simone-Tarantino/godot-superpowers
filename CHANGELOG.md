# Changelog

All notable changes to **godot-superpowers** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [1.3.1] — 2026-05-05

### Fixed
- `orchestrator` agent: dropped `TodoWrite` from declared tools (not portable across Claude Code versions); added `Edit` and `Write`. The orchestrator now updates the plan markdown directly instead of dispatching a worker for every checkbox flip.
- `orchestrator` agent: added a hard retry cap — maximum 2 fix-passes per file after a CRITICAL verifier finding, then escalate to the user. Prevents infinite verify→fix loops.
- `file-verifier` agent: explicit MCP-down downgrade rule. When `godot-docs` MCP is unavailable, every API-correctness finding drops from CRITICAL to WARNING; only syntactic Godot 3.x leftovers and missing type hints stay CRITICAL.
- Verifier-reminder hook: skips when running inside a subagent (`CLAUDE_AGENT_NAME` set), and produces one consolidated line for all changed files instead of one line per file. Less visual noise when the orchestrator is already auto-dispatching the verifier.
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
