---
name: performance-audit
description: Audit a Godot 4.x project for common performance pitfalls — repeated node lookups, _process abuse, missing pooling, untyped collections, missing occlusion, heavy fragment shaders. Reports findings with severity and fix.
allowed-tools: Read, Grep, Glob, Bash
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Performance Audit

Static-analysis-style scan plus runtime suggestions. Run this when frame rate drops, before a milestone, or when adding many entities at once.

## Audit checklist

### 1. Repeated node lookups in hot paths

```bash
grep -rn '\$' --include='*.gd' scripts/ scenes/ | \
    grep -E '_process|_physics_process' | \
    grep -v '@onready'
```

Any `$Path` or `get_node()` inside `_process` / `_physics_process` is a candidate for `@onready`. Severity: **HIGH**.

### 2. `find_child` / `find_node` calls

```bash
grep -rn 'find_child\|find_node' --include='*.gd'
```

`find_child` walks the tree. Use unique names (`%`) or direct `@onready` references. Severity: **HIGH**.

### 3. Untyped collections used for homogeneous data

```bash
grep -rn ': Array =\|: Dictionary =' --include='*.gd' scripts/
```

Replace `Array` → `Array[T]`, `Dictionary` → `Dictionary[K, V]` where contents are uniform. Severity: **MEDIUM**.

### 4. `_process` running on idle nodes

Any node with `_process` but no actual work happening every frame:

```bash
grep -B 1 -A 5 'func _process' --include='*.gd' -rn scripts/
```

Disable with `set_process(false)` until needed, or use `Timer` for periodic work. Severity: **MEDIUM**.

### 5. `instantiate()` in hot loops

```bash
grep -rn 'instantiate' --include='*.gd' scripts/ | \
    grep -v '_ready\|enter\|setup'
```

Frequent instantiation = pool candidate. Severity: **HIGH** if in `_process` / `_physics_process` / spawn loops.

### 6. `load()` where `preload()` works

```bash
grep -rn 'load(' --include='*.gd' scripts/ | grep -v 'preload\|^.*://\|"user://'
```

If the path is a string literal, switch to `preload`. Severity: **LOW** but free.

### 7. `change_scene_to_file` repeated

```bash
grep -rn 'change_scene_to_file' --include='*.gd'
```

Re-parses on every call. Switch to `change_scene_to_packed(packed)` with a preloaded `PackedScene`. Severity: **MEDIUM**.

### 8. Missing `@onready` for cached refs

```bash
grep -rn '^var .* = \$' --include='*.gd'
```

`var x = $X` runs at instantiation, not when the tree is ready — fragile. Always `@onready`. Severity: **HIGH** (correctness too).

### 9. TileMap (deprecated in 4.3+)

```bash
grep -rn '\[node .* type="TileMap"\]' --include='*.tscn'
```

Migrate to `TileMapLayer` (one node per layer). Severity: **MEDIUM**.

### 10. ParallaxBackground / ParallaxLayer (deprecated in 4.3+)

```bash
grep -rn 'type="ParallaxBackground"\|type="ParallaxLayer"' --include='*.tscn'
```

Migrate to `Parallax2D`. Severity: **LOW**.

### 11. Particles config

Check for `GPUParticles2D` / `GPUParticles3D` with `amount` over a few thousand or `process_material` rebuilt every emit. Severity: **MEDIUM**.

### 12. Many identical meshes

If 100+ instances of the same mesh, suggest `MultiMeshInstance3D` (or `MultiMeshInstance2D`). Severity: **HIGH** for stress scenes.

### 13. Missing occlusion (3D)

Project has 3D scenes but no `OccluderInstance3D` / Occlusion Culling enabled in the World Environment? Severity: **MEDIUM**.

### 14. Missing `VisibleOnScreenNotifier` for off-screen entities

Entities that `_physics_process` even when off-screen can be cheaper if disabled when invisible. Severity: **LOW**.

### 15. Fragment shader cost

Look for shaders with:
- Loops over more than ~16 iterations
- Multiple `texture()` calls with `screen_texture` / `depth_texture`
- Per-pixel matrix math

Severity: **HIGH** on web/mobile, MEDIUM on desktop.

### 16. Resource not duplicated when mutated

```bash
grep -rn '\.tres' --include='*.gd' | grep -v 'duplicate\|preload'
```

Mutating a shared `Resource` mutates it for every consumer. Severity: **HIGH** (bug, not just perf).

### 17. Signal connected multiple times

```bash
grep -rn '\.connect(' --include='*.gd' | wc -l
# review for any signal connected in _ready of an instanced scene that's spawned often
```

Without `CONNECT_ONE_SHOT` or a guard, repeated connects trigger duplicate handlers. Severity: **MEDIUM** (bug + perf).

### 18. `_input` vs `_unhandled_input`

`_input` runs even after UI consumes the event. Use `_unhandled_input` unless you specifically need to override UI. Severity: **LOW**.

## Runtime profiling

Direct the user to:

1. **Debugger → Profiler** — start before reproducing, sort by self time. Look for unexpected `_process` consumers.
2. **Debugger → Visual Profiler** — GPU-side, identifies render passes.
3. **Debugger → Monitor**:
   - **Object Count** — should be stable; growth = leak
   - **Node Count** — bounded; growth in a long session = orphaned scenes
   - **Resource Count** — bounded; same logic
   - **FPS** — drops correlate with what frame in transcript
4. `Engine.get_frames_per_second()` — log periodically during the suspect activity.
5. `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` — if > ~3000 on desktop or > ~1000 on web/mobile, batch with MultiMesh.

## Reporting format

```
=== Performance Audit ===

HIGH (3 findings):
  scripts/player/player.gd:42 — get_node("Sprite2D") in _physics_process; cache via @onready
  scripts/enemies/spawner.gd:88 — instantiate() in _process; pool via genre-pack
  scenes/level_01.tscn — 600 identical TreeMesh instances; switch to MultiMeshInstance3D

MEDIUM (5 findings):
  ...

LOW (2 findings):
  ...

Recommended next steps:
  1. Apply HIGH fixes
  2. Profile after each fix to confirm impact
  3. Re-run audit
```

## Anti-pattern reference

| Anti-pattern | Symptom | Fix |
|--------------|---------|-----|
| `$Path` lookup in `_process` | Stable frame drop on a scene | `@onready` |
| `instantiate()` in spawn loop | Frame hitches on burst | Object pool |
| Shared `Resource` mutated | Confusing stat / progression bugs | `.duplicate(true)` |
| `_process` on idle entities | High idle CPU | `set_process(false)` until needed |
| `_input` instead of `_unhandled_input` | Input fires through UI | Switch to `_unhandled_input` |
| Untyped `Array` | Missed compile-time errors | `Array[T]` |
| 100+ identical MeshInstance3D | GPU draw call spike | `MultiMeshInstance3D` |
| Heavy fragment shader on big quad | GPU fragment-bound | Reduce sample count, simpler ops |
| Big `_physics_process` switch on `state` | Hard to refactor | State machine (`create-state-machine`) |

## See also

- Run `code-reviewer` agent for a deeper GDScript review (overlaps slightly with this audit but goes wider into correctness)
- `performance-profiler` agent — for interactive investigation with the profiler
