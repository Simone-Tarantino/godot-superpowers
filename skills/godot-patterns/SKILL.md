---
name: godot-patterns
description: Godot 4.x reference — GDScript style, scene composition, signals, autoloads, common 2D/3D patterns, Tween, Area input, and Godot 3.x to 4.x migration. Auto-loads when working with .gd or .tscn files.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
paths: ["**/*.gd", "**/*.tscn", "**/*.tres", "project.godot"]
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Godot 4.x Patterns Reference

Source-of-truth: [Godot docs](https://docs.godotengine.org/en/stable/) and [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

## GDScript style essentials

```gdscript
class_name Player
extends CharacterBody2D

## Player controller. Extends docstring at file top is rendered in editor help.

signal health_changed(old: int, new: int)
signal died

enum State { IDLE, RUN, JUMP, FALL }

const MAX_SPEED := 250.0
const JUMP_VELOCITY := -400.0

@export var max_health: int = 100
@export_range(0.0, 1.0) var move_smoothing: float = 0.15
@export var bullet_scene: PackedScene

var current_health: int
var _state: State = State.IDLE

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hurtbox: Area2D = %Hurtbox  # unique name access


func _ready() -> void:
    current_health = max_health
    _hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func take_damage(amount: int) -> void:
    var prev := current_health
    current_health = maxi(0, current_health - amount)
    health_changed.emit(prev, current_health)
    if current_health == 0:
        died.emit()


func _on_hurtbox_area_entered(area: Area2D) -> void:
    if area.is_in_group("enemy_hitbox"):
        take_damage(area.damage)
```

### Naming

| Item | Convention | Example |
|------|------------|---------|
| File / folder | `snake_case` | `player_controller.gd` |
| `class_name`, classes | `PascalCase` | `class_name PlayerController` |
| Functions, vars, signals | `snake_case` | `take_damage`, `health_changed` |
| Constants | `CONSTANT_CASE` | `MAX_SPEED` |
| Enum type / members | `PascalCase` / `CONSTANT_CASE` | `enum State { IDLE, RUN }` |
| Private | leading `_` | `_internal_state` |
| Node names in scene | `PascalCase` | `PlayerCamera` |
| Signal names | past tense | `health_changed`, `enemy_killed` |

### Member order (style guide)

`@tool` / `@icon` → `class_name` / `extends` → docstring → signals → enums → consts → static vars → `@export` vars → vars → `@onready` vars → `_init` → `_ready` → other virtual `_*` → public methods → private `_methods` → inner classes.

Two blank lines between functions. Tabs for indent. 100-char soft limit. Double quotes by default.

### Type hints (mandatory in 4.x)

```gdscript
@export var max_health: int = 100
@onready var _sprite: Sprite2D = $Sprite2D
var velocity := Vector2.ZERO              # inferred type
var enemies: Array[Enemy] = []            # typed array
var stats: Dictionary[String, int] = {}   # typed dict (4.4+)
func heal(amount: int) -> void: ...
```

## Scene composition

- **Composition over inheritance.** Build behavior by composing component child nodes (`HealthComponent`, `HitboxComponent`, `StateMachine`) rather than 3+-deep `extends` chains.
- **Scene** when there's a hierarchy or designer-tweakable values; **script-only Node** when behavior is purely imperative; **Resource** when it's pure data.
- **One responsibility per scene.** Cross-scene wiring via signals or autoloads, never `get_node("/root/Main/Player")` traversal.
- **Instance with `preload()`**, not `load()`, when path is static:

```gdscript
const BulletScene := preload("res://scenes/bullet.tscn")

func shoot() -> void:
    var b := BulletScene.instantiate()
    add_child(b)
```

- **Scene transitions:** prefer `change_scene_to_packed(packed_scene)` over `change_scene_to_file(path)` (no re-parse). Wrap in autoload `SceneManager` with fade transition.

## Signals

```gdscript
# Declaration (typed args!)
signal health_changed(old: int, new: int)

# Emission
health_changed.emit(prev, current)

# Connection (in code, in _ready, never via editor)
button.pressed.connect(_on_button_pressed)
button.pressed.connect(_attack.bind("heavy"))   # Callable.bind for partial args
button.pressed.connect(_on_pressed, CONNECT_ONE_SHOT)
```

**Decision rule:**

| Pattern | Use when |
|---------|----------|
| Direct `@onready` ref | Stable parent-child or unique-name (`%`) sibling |
| Local signal | One emitter, N listeners; same scene tree neighborhood |
| EventBus signal | Emitter + listener live in unrelated scenes |
| Group + `call_group` | Many-to-many broadcasts; listeners come and go |

## Autoloads

Register in **Project Settings → Globals → Autoload**. Use the `create-autoload` skill to scaffold and register at once. Common ones:

| Autoload | Role |
|----------|------|
| `EventBus` | Cross-scene signals only |
| `GameState` | Run-scoped data: score, level, flags |
| `SceneManager` | Scene swaps + transitions |
| `AudioManager` | Bus volumes, SFX/music pool |
| `SaveManager` | Serialize/deserialize via Resource |
| `InputManager` | Action remap, device tracking |
| `SettingsManager` | Config (resolution, language, accessibility) |

**Don't autoload** anything tied to a specific scene's lifecycle, anything heavy in `_process`, or anything you'd want multiple instances of. Never `queue_free()` an autoload.

## 3D input via Area3D / Area2D

```gdscript
func _ready() -> void:
    var area: Area3D = $Area3D
    area.input_event.connect(_on_area_input_event)
    area.mouse_entered.connect(_on_mouse_entered)


func _on_area_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3,
        _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
```

For 2D use `Area2D.input_event(viewport, event, shape_idx)`. Set `input_pickable = true` on the Area.

## Tween (gameplay animation)

```gdscript
# Parallel scale + position
var tw := create_tween().set_parallel()
tw.tween_property(self, "scale", Vector3.ONE * 1.2, 0.15)
tw.tween_property(self, "position:y", target_y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Sequence with callback
var seq := create_tween()
seq.tween_property(self, "modulate:a", 0.0, 0.3)
seq.tween_callback(queue_free)
```

Use `Tween` for gameplay (created on demand, garbage-collected). Use `AnimationPlayer` for hand-keyframed animations and `AnimationTree` for blending state machines.

## Resources (custom data classes)

```gdscript
# resources/item.gd
class_name Item
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var max_stack: int = 1
@export_multiline var description: String
```

Then `@export var starting_item: Item` lets designers drag a `.tres` instance in the Inspector. **Caveat:** `.duplicate()` resources mutated at runtime — `load()` returns the same shared instance.

## `_process` vs `_physics_process` vs `_unhandled_input`

| Callback | Use for |
|----------|---------|
| `_process(delta)` | Visuals, UI, camera follow, non-physics interpolation |
| `_physics_process(delta)` | Movement, collision queries, physics-tied AI (fixed timestep) |
| `_unhandled_input(event)` | Input handling (only fires when not consumed by UI) |
| `_input(event)` | Input that must run even before UI handles it |

Disable when idle: `set_process(false)`, `set_physics_process(false)`, or `process_mode = PROCESS_MODE_DISABLED`.

## Pause

```gdscript
get_tree().paused = true

# Per-node behavior:
# PROCESS_MODE_INHERIT (default), PROCESS_MODE_PAUSABLE,
# PROCESS_MODE_WHEN_PAUSED, PROCESS_MODE_ALWAYS, PROCESS_MODE_DISABLED
$PauseMenu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
$Music.process_mode = Node.PROCESS_MODE_ALWAYS
```

## Project structure (recommended)

```
project.godot
addons/                # plugins (gut, dialogic, phantom_camera, ...)
autoload/              # singletons (event_bus.gd, game_state.gd)
scenes/                # .tscn grouped by feature
  player/
  enemies/
  ui/
  levels/
scripts/               # reusable scripts not bound to one scene
  components/          # health_component.gd, hurtbox.gd
  state_machine/
resources/             # .tres data (items/, abilities/)
assets/                # raw art/audio (sprites/, audio/, models/)
test/                  # GUT tests
shaders/               # .gdshader files
.gdignore              # in folders Godot should not import
```

## Godot 3.x → 4.x cheatsheet

| Wrong (3.x) | Right (4.x) |
|-------------|-------------|
| `yield(timer, "timeout")` | `await timer.timeout` |
| `export var x = 5` | `@export var x: int = 5` |
| `onready var n = $N` | `@onready var n: Node = $N` |
| `connect("signal", obj, "method")` | `signal_name.connect(callable)` |
| `instance()` | `instantiate()` |
| `Spatial` | `Node3D` |
| `KinematicBody2D` + `move_and_slide(velocity)` | `CharacterBody2D`; set `velocity`; `move_and_slide()` no args |
| `PoolStringArray` | `PackedStringArray` |
| `rand_range(a, b)` | `randf_range(a, b)` |
| `tool` | `@tool` |
| `Reference` | `RefCounted` |
| `change_scene(path)` | `change_scene_to_file(path)` or better `change_scene_to_packed(packed)` |

Use `gdscript-migrator` agent for systematic migration of legacy code.

## Anti-patterns to avoid

- `get_node()` / `find_child()` in `_process` — cache via `@onready`.
- Movement in `_process` — use `_physics_process`.
- Polling `Input.is_action_pressed` in `_process` for one-shot actions — use `_unhandled_input` and `event.is_action_pressed`.
- Cross-scene traversal `get_node("/root/Main/Player")` — use unique names, autoload, or signals.
- Untyped `Array` / `Dictionary` for homogeneous data — use `Array[T]` / `Dictionary[K, V]`.
- `Dictionary` literals for game data — use custom `Resource`.
- JSON for full save state — loses `Vector2`/`Color`/typed objects. Use `Resource` save.
- `extends` chains 3+ deep — compose with child component nodes.
- Connecting a signal in both editor and code — pick one (code preferred).
- Forgetting `process_mode` on UI/menu — pause kills the menu too.
- Mutating shared `Resource` instances — call `.duplicate()` for per-instance state.
- `Array.append()` repeatedly in hot loops — preallocate or reuse.
- `instantiate()` mid-frame in a hot loop — pool instead (see `genre-pack-*` skills).

## See also

- `create-component`, `create-state-machine`, `create-resource` — scaffolding skills
- `setup-collision-layers`, `setup-input-map`, `setup-save-system` — system setup
- `code-reviewer` agent — full GDScript review against this reference
