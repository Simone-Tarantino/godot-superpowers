---
name: genre-pack-3d-action
description: 3D action / 3rd-person pack — SpringArm camera rig, mouse + gamepad camera control, code-driven movement (or root motion), lock-on targeting, dodge roll, hit reactions. Suitable for Soulslike / hack-and-slash / action-adventure.
allowed-tools: Read, Write, Edit
---

# Genre Pack: 3D Action

3rd-person 3D action pack. Camera rig + character controller + lock-on system.

## Camera rig (SpringArm3D)

The standard 3rd-person rig:

```
CameraPivot (Node3D)              -> rotated by input
└── SpringArm3D                    -> collision-aware arm length
    └── Camera3D                    -> child of arm, faces back at the pivot
```

Configure `SpringArm3D`:
- `spring_length`: e.g. 4.0 (max distance back)
- `collision_mask`: bit 1 (World) so it shrinks when blocked
- `shape`: `SphereShape3D` with radius 0.3 (smoother than raycast)
- `margin`: 0.05

`scripts/components/camera_rig.gd`:

```gdscript
class_name CameraRig3D
extends Node3D

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var height_offset: float = 1.5

@export var mouse_sensitivity: float = 0.003
@export var stick_sensitivity: float = 3.0
@export var pitch_min_deg: float = -60.0
@export var pitch_max_deg: float = 70.0
@export var invert_y: bool = false

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if target:
        global_position = global_position.lerp(target.global_position + Vector3.UP * height_offset, follow_speed * delta)
    var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
    if stick.length_squared() > 0.04:
        rotation.y -= stick.x * stick_sensitivity * delta
        rotation.x += stick.y * stick_sensitivity * delta * (1.0 if invert_y else -1.0)
        rotation.x = clampf(rotation.x, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotation.y -= event.relative.x * mouse_sensitivity
        rotation.x += event.relative.y * mouse_sensitivity * (1.0 if invert_y else -1.0)
        rotation.x = clampf(rotation.x, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
    elif event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
```

## 3D character controller

`scripts/components/character_3d_move.gd`:

```gdscript
class_name CharacterMove3D
extends Node

@export var max_speed: float = 5.5
@export var acceleration: float = 30.0
@export var friction: float = 25.0
@export var jump_velocity: float = 5.0
@export var gravity: float = 15.0
@export var rotation_speed: float = 12.0   ## radians/sec

var body: CharacterBody3D

func _ready() -> void:
    body = get_parent() as CharacterBody3D

func physics_step(delta: float, input_dir_world: Vector3, jump_pressed: bool) -> void:
    body.velocity.y -= gravity * delta
    var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
    if input_dir_world.length_squared() > 0.04:
        horiz = horiz.move_toward(input_dir_world * max_speed, acceleration * delta)
        # face movement direction
        var target_yaw := atan2(input_dir_world.x, input_dir_world.z)
        body.rotation.y = lerp_angle(body.rotation.y, target_yaw, rotation_speed * delta)
    else:
        horiz = horiz.move_toward(Vector3.ZERO, friction * delta)
    body.velocity.x = horiz.x
    body.velocity.z = horiz.z
    if jump_pressed and body.is_on_floor():
        body.velocity.y = jump_velocity
    body.move_and_slide()
```

Player wiring:

```gdscript
class_name Player
extends CharacterBody3D

@onready var _move: CharacterMove3D = $CharacterMove3D
@onready var _camera_rig: CameraRig3D = get_tree().get_first_node_in_group("camera_rig")

func _physics_process(delta: float) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var cam_basis := _camera_rig.global_transform.basis
    # project camera basis onto horizontal plane
    var fwd := -Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
    var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
    var input_world := (right * input.x + fwd * -input.y).normalized() * input.length()
    var jump := Input.is_action_just_pressed("jump")
    _move.physics_step(delta, input_world, jump)
```

Note: `input.y` is inverted because Godot's "up" input axis returns -1 (matching screen-space convention).

## Code motion vs root motion

| Approach | When |
|----------|------|
| **Code-driven** (set `velocity`, `move_and_slide()`) | Default. Responsive, predictable, easy to tune. |
| **Root motion** (`AnimationTree.set("parameters/blend_position", ...)` + `AnimationTree.advance()`) | When animation should drive translation — heavy attacks, finishers, scripted dodges. |

For root motion: enable in `AnimationPlayer` track → `Apply Reset` → make the bone hierarchy contain a `Skeleton3D` with `motion_scale` set. Read motion from `AnimationTree.get_root_motion_position()` each frame and apply to `body.velocity`.

## Lock-on targeting

```gdscript
class_name LockOnSystem
extends Node

signal target_changed(new_target: Node3D)

@export var owner_node: Node3D                ## usually the player
@export var max_range: float = 15.0
@export var fov_degrees: float = 90.0
@export var camera_rig: CameraRig3D

var current_target: Node3D

# Use _unhandled_input so UI captures take precedence over gameplay actions.
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("lock_on"):
        if current_target:
            _set_target(null)
        else:
            _set_target(_find_best_target())

func _set_target(t: Node3D) -> void:
    current_target = t
    target_changed.emit(t)

func _find_best_target() -> Node3D:
    var candidates := get_tree().get_nodes_in_group("lockon_targets")
    var best: Node3D = null
    var best_score := -INF
    var owner_pos := owner_node.global_position
    var forward := -owner_node.global_transform.basis.z
    for n in candidates:
        var node := n as Node3D
        if node == owner_node:
            continue
        var to := node.global_position - owner_pos
        var dist := to.length()
        if dist > max_range:
            continue
        var dir := to / dist
        var dot := forward.dot(dir)
        if dot < cos(deg_to_rad(fov_degrees / 2.0)):
            continue
        # score: prefer close + centered
        var score := dot - dist * 0.05
        if score > best_score:
            best_score = score
            best = node
    return best

func _physics_process(_delta: float) -> void:
    # rotate camera and player toward target
    if current_target and is_instance_valid(current_target):
        var to := current_target.global_position - owner_node.global_position
        var yaw := atan2(to.x, to.z)
        owner_node.rotation.y = lerp_angle(owner_node.rotation.y, yaw, 12.0 * get_physics_process_delta_time())
        camera_rig.rotation.y = yaw
```

Targets join `lockon_targets` group via `add_to_group("lockon_targets")` in `_ready()`.

## Dodge roll

```gdscript
class_name DodgeRoll
extends Node

@export var roll_speed: float = 12.0
@export var roll_duration: float = 0.45
@export var roll_cooldown: float = 0.6
@export var iframes_start: float = 0.05
@export var iframes_end: float = 0.35

var _t: float = 0.0
var _cd: float = 0.0
var _dir: Vector3
var _is_rolling: bool = false
var body: CharacterBody3D

func _ready() -> void:
    body = get_parent() as CharacterBody3D

func _physics_process(delta: float) -> void:
    _cd = maxf(0.0, _cd - delta)
    if _is_rolling:
        _t += delta
        body.velocity.x = _dir.x * roll_speed
        body.velocity.z = _dir.z * roll_speed
        var hp := body.get_node("HealthComponent") as HealthComponent
        if hp:
            hp.invulnerable = (_t >= iframes_start and _t <= iframes_end)
        if _t >= roll_duration:
            _is_rolling = false
            if hp:
                hp.invulnerable = false

func try_roll(dir: Vector3) -> bool:
    if _is_rolling or _cd > 0.0 or dir.length_squared() < 0.04:
        return false
    _is_rolling = true
    _t = 0.0
    _cd = roll_cooldown
    _dir = dir.normalized()
    return true
```

## Hit reactions

```gdscript
# In Player or Enemy script
func _on_hit(damage: int, source: Node) -> void:
    var anim := $AnimationTree as AnimationTree
    anim.set("parameters/HitReact/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
    if source:
        var knockback := (global_position - source.global_position).normalized() * 5.0
        velocity += knockback
    # screen shake / camera punch
    EventBus.camera_shake_requested.emit(0.4, 0.15)
```

## Animation tree

For 3rd-person rigs, set up an `AnimationTree` with:
- **BlendSpace1D** for locomotion (idle ↔ walk ↔ run, parameter = speed)
- **OneShot** for actions (attack, dodge, hit, jump)
- **StateMachine** for high-level states (alive ↔ dead ↔ stagger)

Drive parameters from code:
```gdscript
anim_tree.set("parameters/Locomotion/blend_position", velocity.length() / max_speed)
anim_tree.set("parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
```
