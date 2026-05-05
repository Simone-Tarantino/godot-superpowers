---
name: genre-pack-topdown
description: Top-down 2D pack — 8-direction movement, snap-to-grid optional, A* pathfinding for AI, twin-stick aiming, top-down camera follow. For Hotline Miami / Enter the Gungeon / classic RPG style.
allowed-tools: Read, Write, Edit
---

# Genre Pack: Top-Down 2D

Movement, AI, aiming, and camera for top-down 2D games.

## Top-down move component

```gdscript
class_name TopDownMoveComponent
extends Node

@export var max_speed: float = 200.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

var body: CharacterBody2D

func _ready() -> void:
    body = get_parent() as CharacterBody2D
    assert(body, "TopDownMoveComponent parent must be CharacterBody2D")

func physics_step(delta: float, input_dir: Vector2) -> void:
    if input_dir.length_squared() > 0.01:
        body.velocity = body.velocity.move_toward(input_dir.normalized() * max_speed, acceleration * delta)
    else:
        body.velocity = body.velocity.move_toward(Vector2.ZERO, friction * delta)
    body.move_and_slide()
```

Player code:

```gdscript
func _physics_process(delta: float) -> void:
    var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    _move.physics_step(delta, input_dir)
```

## Snap-to-grid movement (turn-based / tactical)

```gdscript
class_name GridMover
extends Node

const TILE_SIZE := 32.0

@export var move_duration: float = 0.15

var body: Node2D
var _tween: Tween
var is_moving: bool = false

func _ready() -> void:
    body = get_parent() as Node2D

func step(direction: Vector2i) -> bool:
    if is_moving or direction == Vector2i.ZERO:
        return false
    var target := body.position + Vector2(direction) * TILE_SIZE
    if _is_blocked(target):
        return false
    is_moving = true
    if _tween:
        _tween.kill()
    _tween = create_tween()
    _tween.tween_property(body, "position", target, move_duration)
    _tween.finished.connect(func() -> void: is_moving = false)
    return true

func _is_blocked(_target: Vector2) -> bool:
    # check tilemap or other obstacles
    return false
```

## Twin-stick aiming

```gdscript
# In _physics_process or _process
var aim_dir: Vector2

# Mouse aiming (top-down with mouse)
aim_dir = (get_global_mouse_position() - global_position).normalized()

# Right-stick aiming (gamepad)
var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
if stick.length_squared() > 0.04:  # deadzone
    aim_dir = stick.normalized()

# Apply to weapon / cursor
$WeaponPivot.rotation = aim_dir.angle()
```

## A* pathfinding

For grid-based worlds, `AStarGrid2D` is the right tool. For free-form, use `NavigationAgent2D`.

### Grid-based (`AStarGrid2D`)

```gdscript
class_name GridPathfinder
extends Node2D

@export var tilemap: TileMapLayer
@export var solid_layer: int = 0
@export var solid_terrain: int = 0  # which terrain ID is wall

var _astar := AStarGrid2D.new()

func _ready() -> void:
    if not tilemap:
        return
    var rect := tilemap.get_used_rect()
    _astar.region = rect
    _astar.cell_size = Vector2(tilemap.tile_set.tile_size)
    _astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
    _astar.update()
    for x in rect.size.x:
        for y in rect.size.y:
            var coord := rect.position + Vector2i(x, y)
            var data := tilemap.get_cell_tile_data(coord)
            if data and data.get_custom_data("is_solid"):
                _astar.set_point_solid(coord, true)

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
    var from_cell := tilemap.local_to_map(tilemap.to_local(from))
    var to_cell := tilemap.local_to_map(tilemap.to_local(to))
    return _astar.get_point_path(from_cell, to_cell)
```

### Free-form (`NavigationAgent2D`)

Set up:
1. Add `NavigationRegion2D` to the level scene; bake its `NavigationPolygon` to cover walkable area
2. Add `NavigationAgent2D` to each AI entity
3. Set `target_position`, follow `get_next_path_position()`

```gdscript
class_name TopDownEnemy
extends CharacterBody2D

@onready var _agent: NavigationAgent2D = $NavigationAgent2D
@onready var _move: TopDownMoveComponent = $TopDownMoveComponent

@export var target: Node2D

func _physics_process(delta: float) -> void:
    if not target:
        _move.physics_step(delta, Vector2.ZERO)
        return
    _agent.target_position = target.global_position
    if _agent.is_navigation_finished():
        _move.physics_step(delta, Vector2.ZERO)
        return
    var next := _agent.get_next_path_position()
    var dir := (next - global_position).normalized()
    _move.physics_step(delta, dir)
```

## Top-down camera

```gdscript
class_name TopDownCamera
extends Camera2D

@export var target: Node2D
@export var smoothing: float = 8.0
@export var aim_offset_factor: float = 0.3   ## camera leans toward aim direction
@export var max_offset: float = 80.0

func _physics_process(delta: float) -> void:
    if not target:
        return
    var aim_offset := Vector2.ZERO
    if target.has_method("get_aim_dir"):
        aim_offset = target.get_aim_dir() * max_offset * aim_offset_factor
    var desired := target.global_position + aim_offset
    global_position = global_position.lerp(desired, smoothing * delta)
```

## Field of view / line of sight

For stealth or shooting AI:

```gdscript
func can_see(target: Node2D, max_range: float, fov_degrees: float) -> bool:
    var to_target := target.global_position - global_position
    if to_target.length() > max_range:
        return false
    var forward := Vector2.RIGHT.rotated(rotation)  # or facing dir
    if forward.angle_to(to_target) > deg_to_rad(fov_degrees / 2.0):
        return false
    var space := get_world_2d().direct_space_state
    var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)  # World layer
    query.exclude = [self]
    var result := space.intersect_ray(query)
    return result.is_empty()  # nothing blocked the ray
```

## Bullet hell tips

- Use `MultiMeshInstance2D` for bullets if rendering many hundreds
- Or use a pool (see `genre-pack-platformer` BulletPool example)
- Bullets as `Area2D` (no physics, just collision) — much cheaper than `RigidBody2D`
- Disable bullets when off-screen (`VisibleOnScreenNotifier2D`)
- Spatial partitioning isn't usually needed in 2D Godot — the engine handles it
