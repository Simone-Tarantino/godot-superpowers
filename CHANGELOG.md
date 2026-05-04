# Changelog

All notable changes to **godot-superpowers** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

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
