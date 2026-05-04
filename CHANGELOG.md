# Changelog

All notable changes to **godot-superpowers** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

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
