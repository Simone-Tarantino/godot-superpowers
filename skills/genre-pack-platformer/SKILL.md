---
name: genre-pack-platformer
description: 2D platformer movement pack — coyote time, jump buffer, variable jump height, snappy controls, wall jump, dash, double jump. Drop-in MoveComponent + States with tuned defaults. For Celeste / Hollow Knight / Mario-style feel.
allowed-tools: Read, Write, Edit
---

# Genre Pack: 2D Platformer

Battle-tested platformer movement. Tune the constants — defaults give a snappy mid-air feel similar to Celeste / Hollow Knight.

## Tuning constants reference

```gdscript
# scripts/components/platformer_move_component.gd
class_name PlatformerMoveComponent
extends Node

# Horizontal
@export var max_speed: float = 250.0
@export var ground_acceleration: float = 1800.0
@export var ground_friction: float = 1800.0
@export var air_acceleration: float = 1000.0
@export var air_friction: float = 600.0

# Jump
@export var jump_velocity: float = -400.0
@export var jump_cut_factor: float = 0.5     ## velocity multiplier on early release
@export var coyote_time: float = 0.10        ## seconds after leaving ground you can still jump
@export var jump_buffer_time: float = 0.10   ## seconds before landing where jump press still counts

# Gravity
@export var gravity: float = 980.0
@export var fall_gravity_multiplier: float = 1.6   ## faster falling = snappier feel
@export var max_fall_speed: float = 500.0

# Air control
@export var max_air_jumps: int = 0           ## 1 = double jump, 2 = triple, etc.

# Wall mechanics
@export var wall_slide_max_speed: float = 80.0
@export var wall_jump_velocity: Vector2 = Vector2(220.0, -380.0)
@export var wall_jump_lockout: float = 0.15  ## input ignore time after wall jump

# Dash
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.5

# State (read-only outside)
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _air_jumps_remaining: int = 0
var _wall_lock: float = 0.0
var _dash_time: float = 0.0
var _dash_cd: float = 0.0
var body: CharacterBody2D

func _ready() -> void:
    body = get_parent() as CharacterBody2D
    assert(body, "PlatformerMoveComponent parent must be CharacterBody2D")

func physics_step(delta: float, input_x: float, jump_pressed: bool, jump_released: bool, dash_pressed: bool) -> void:
    _wall_lock = maxf(0.0, _wall_lock - delta)
    _dash_cd = maxf(0.0, _dash_cd - delta)

    # Dash overrides everything
    if _dash_time > 0.0:
        _dash_time -= delta
        body.velocity.x = sign(body.velocity.x if body.velocity.x != 0.0 else input_x) * dash_speed
        body.velocity.y = 0.0
        body.move_and_slide()
        return
    if dash_pressed and _dash_cd <= 0.0 and absf(input_x) > 0.05:
        _dash_time = dash_duration
        _dash_cd = dash_cooldown
        return

    # Gravity
    var g := gravity * (fall_gravity_multiplier if body.velocity.y > 0.0 else 1.0)
    body.velocity.y = minf(body.velocity.y + g * delta, max_fall_speed)

    # Wall slide
    var on_wall := body.is_on_wall_only()
    if on_wall and body.velocity.y > 0.0:
        body.velocity.y = minf(body.velocity.y, wall_slide_max_speed)

    # Horizontal
    if _wall_lock <= 0.0:
        if absf(input_x) > 0.05:
            var accel := ground_acceleration if body.is_on_floor() else air_acceleration
            body.velocity.x = move_toward(body.velocity.x, input_x * max_speed, accel * delta)
        else:
            var fric := ground_friction if body.is_on_floor() else air_friction
            body.velocity.x = move_toward(body.velocity.x, 0.0, fric * delta)

    # Coyote + jump buffer
    if body.is_on_floor():
        _coyote = coyote_time
        _air_jumps_remaining = max_air_jumps
    else:
        _coyote = maxf(0.0, _coyote - delta)
    if jump_pressed:
        _jump_buffer = jump_buffer_time
    else:
        _jump_buffer = maxf(0.0, _jump_buffer - delta)

    # Jump resolution
    if _jump_buffer > 0.0:
        if _coyote > 0.0:
            body.velocity.y = jump_velocity
            _jump_buffer = 0.0
            _coyote = 0.0
        elif on_wall:
            body.velocity.y = wall_jump_velocity.y
            body.velocity.x = -sign(body.get_wall_normal().x) * wall_jump_velocity.x  # away from wall
            _wall_lock = wall_jump_lockout
            _jump_buffer = 0.0
        elif _air_jumps_remaining > 0:
            body.velocity.y = jump_velocity
            _air_jumps_remaining -= 1
            _jump_buffer = 0.0

    # Variable jump height (cut on release)
    if jump_released and body.velocity.y < 0.0:
        body.velocity.y *= jump_cut_factor

    body.move_and_slide()

func is_dashing() -> bool:
    return _dash_time > 0.0
```

> **Important**: `physics_step()` already calls `body.move_and_slide()` after writing `body.velocity`. The owning `CharacterBody2D` MUST NOT call `move_and_slide()` again in the same frame, and MUST NOT mutate `velocity` after delegating to the component — that would either re-process the same motion or stomp the component's writes. Pattern: read input in `_physics_process`, hand it to the component, and let the component own the body's velocity + slide for that frame.

## Player wiring

```gdscript
class_name Player
extends CharacterBody2D

@onready var _move: PlatformerMoveComponent = $PlatformerMoveComponent
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
    var input_x := Input.get_axis("move_left", "move_right")
    var jump_pressed := Input.is_action_just_pressed("jump")
    var jump_released := Input.is_action_just_released("jump")
    var dash_pressed := Input.is_action_just_pressed("dash")

    _move.physics_step(delta, input_x, jump_pressed, jump_released, dash_pressed)

    if absf(input_x) > 0.05:
        _sprite.flip_h = input_x < 0.0
    _update_animation()

func _update_animation() -> void:
    if _move.is_dashing():
        _sprite.play("dash")
    elif not is_on_floor():
        _sprite.play("jump" if velocity.y < 0.0 else "fall")
    elif absf(velocity.x) > 10.0:
        _sprite.play("run")
    else:
        _sprite.play("idle")
```

## Tuning cookbook

| Feel | Adjustments |
|------|-------------|
| **Snappier (Celeste-like)** | Higher `ground_acceleration` (3000+), shorter `jump_buffer` (0.08), higher `fall_gravity_multiplier` (2.0) |
| **Floaty (Mario-like)** | Lower gravity (700), lower `fall_gravity_multiplier` (1.2), longer `coyote_time` (0.15) |
| **Heavy (Hollow Knight)** | Lower `max_speed` (200), high `ground_friction`, gravity 1100 |
| **Speedrunner (Sonic)** | Very high `max_speed` (450+), `air_acceleration` ≈ `ground_acceleration` |

## Bonus: Camera follow with deadzone

`scripts/components/platformer_camera.gd`:

```gdscript
class_name PlatformerCamera
extends Camera2D

@export var target: Node2D
@export var deadzone: Vector2 = Vector2(40.0, 30.0)
@export var lerp_speed: float = 5.0
@export var look_ahead_x: float = 60.0

var _target_pos: Vector2

func _physics_process(delta: float) -> void:
    if not target:
        return
    var t := target.global_position
    var diff := t - global_position
    if absf(diff.x) > deadzone.x:
        _target_pos.x = t.x - sign(diff.x) * deadzone.x
        _target_pos.x += sign(target.velocity.x if target.has_method("get_velocity") else 0.0) * look_ahead_x
    if absf(diff.y) > deadzone.y:
        _target_pos.y = t.y - sign(diff.y) * deadzone.y
    global_position = global_position.lerp(_target_pos, lerp_speed * delta)
```

## Object pool (for projectiles in shoot-em-up platformers)

```gdscript
class_name BulletPool
extends Node

@export var bullet_scene: PackedScene
@export var initial_size: int = 32

var _free: Array[Node] = []
var _active: Array[Node] = []

func _ready() -> void:
    for i in initial_size:
        var b := bullet_scene.instantiate()
        b.set_process(false)
        b.set_physics_process(false)
        b.visible = false
        add_child(b)
        _free.append(b)

func acquire() -> Node:
    var b: Node = _free.pop_back() if not _free.is_empty() else bullet_scene.instantiate()
    if b.get_parent() == null:
        add_child(b)
    b.set_process(true)
    b.set_physics_process(true)
    b.visible = true
    _active.append(b)
    return b

func release(b: Node) -> void:
    b.set_process(false)
    b.set_physics_process(false)
    b.visible = false
    _active.erase(b)
    _free.append(b)
```

Each bullet calls `bullet_pool.release(self)` instead of `queue_free()`.
