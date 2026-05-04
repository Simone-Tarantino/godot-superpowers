---
name: create-state-machine
description: Scaffold a node-based finite state machine — StateMachine parent + State child template. Each state is a node, transitions are signals. Inspector-tweakable, testable in isolation.
allowed-tools: Read, Write, Edit, Glob
argument-hint: <entity-name> [state-list...]
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Create State Machine

Generate a node-based FSM. Compared to class-based / dictionary-based FSMs:

✅ Each state is a Node — visible in scene tree, Inspector-tweakable
✅ States can have their own children (timers, animation refs)
✅ Transitions go through a single signal — easy to log/debug
✅ Substituting a state for testing = swap a node

## Files

### `scripts/state_machine/state_machine.gd`

```gdscript
class_name StateMachine
extends Node
## Holds State child nodes; forwards engine callbacks to current state.
## States transition by emitting `transitioned(next_state_name)`.

signal state_changed(old: StringName, new: StringName)

@export var initial_state: NodePath
@export var debug: bool = false

var current_state: State
var states: Dictionary[StringName, State] = {}


func _ready() -> void:
    for child in get_children():
        if child is State:
            states[StringName(child.name)] = child
            child.transitioned.connect(_on_state_transitioned)
    if initial_state:
        current_state = get_node(initial_state) as State
    elif not states.is_empty():
        current_state = states.values()[0]
    if current_state:
        current_state.enter({})


func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)


func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
    if current_state:
        current_state.handle_input(event)


func change_state(target: StringName, payload: Dictionary = {}) -> void:
    if not states.has(target):
        push_warning("StateMachine: missing state '%s'" % target)
        return
    var old := StringName(current_state.name) if current_state else &""
    if current_state:
        current_state.exit()
    current_state = states[target]
    if debug:
        print("[FSM] %s -> %s" % [old, target])
    state_changed.emit(old, target)
    current_state.enter(payload)


func _on_state_transitioned(target: StringName, payload: Dictionary) -> void:
    change_state(target, payload)
```

### `scripts/state_machine/state.gd`

```gdscript
class_name State
extends Node
## Base class. Override the lifecycle callbacks.
## To transition: emit `transitioned(target_state_name, optional_payload_dict)`.

signal transitioned(target: StringName, payload: Dictionary)


func enter(_payload: Dictionary) -> void:
    pass


func exit() -> void:
    pass


func update(_delta: float) -> void:
    pass


func physics_update(_delta: float) -> void:
    pass


func handle_input(_event: InputEvent) -> void:
    pass
```

## Concrete state example

`scripts/states/player_idle.gd`:

```gdscript
class_name PlayerIdleState
extends State

@export var move_threshold: float = 0.05


func enter(_payload: Dictionary) -> void:
    var player := owner as CharacterBody2D
    var anim := player.get_node("AnimationPlayer") as AnimationPlayer
    anim.play("idle")
    player.velocity.x = 0.0


func physics_update(_delta: float) -> void:
    var input_x := Input.get_axis("move_left", "move_right")
    if absf(input_x) > move_threshold:
        transitioned.emit(&"Run", {})
    if Input.is_action_just_pressed("jump") and (owner as CharacterBody2D).is_on_floor():
        transitioned.emit(&"Jump", {})
    if not (owner as CharacterBody2D).is_on_floor():
        transitioned.emit(&"Fall", {})
```

`scripts/states/player_run.gd`:

```gdscript
class_name PlayerRunState
extends State

@export var max_speed: float = 250.0
@export var acceleration: float = 1500.0


func enter(_payload: Dictionary) -> void:
    (owner.get_node("AnimationPlayer") as AnimationPlayer).play("run")


func physics_update(delta: float) -> void:
    var player := owner as CharacterBody2D
    var input_x := Input.get_axis("move_left", "move_right")
    if absf(input_x) < 0.05:
        transitioned.emit(&"Idle", {})
        return
    player.velocity.x = move_toward(player.velocity.x, input_x * max_speed, acceleration * delta)
    if Input.is_action_just_pressed("jump") and player.is_on_floor():
        transitioned.emit(&"Jump", {})
    if not player.is_on_floor():
        transitioned.emit(&"Fall", {})
```

## Scene structure

```
Player (CharacterBody2D)
├── ...other components...
└── StateMachine (StateMachine, initial_state = "Idle")
    ├── Idle (State, script: player_idle.gd)
    ├── Run (State, script: player_run.gd)
    ├── Jump (State, script: player_jump.gd)
    └── Fall (State, script: player_fall.gd)
```

Names of child nodes (`Idle`, `Run`, etc.) are the keys used in `change_state(&"Idle")`.

## Hierarchical / parallel state machines

For complex characters (e.g. ground state machine + weapon state machine running in parallel), nest:

```
Player
└── StateMachines (Node)
    ├── Movement (StateMachine)
    │   ├── Idle / Run / Jump / Fall
    └── Combat (StateMachine)
        ├── Unarmed / Holding / Aiming / Attacking
```

Each `StateMachine` runs independently; states emit signals that the other machine listens to (e.g. movement's `Hit` state pauses combat).

## Behavior tree alternative

For AI with many fallback behaviors (search → patrol → idle), a state machine becomes spaghetti. Use a **behavior tree**:
- [Beehave](https://github.com/bitbrain/beehave) — battle-tested, well-documented
- [LimboAI](https://github.com/limbonaut/limboai) — C++ engine module, FSM + BT hybrid, very fast

Use `addon-curator` agent to install one.

## Testing a state machine

```gdscript
extends GutTest

const PlayerScene := preload("res://scenes/player/player.tscn")


func test_idle_to_run_on_input() -> void:
    var player := add_child_autofree(PlayerScene.instantiate())
    var sm := player.get_node("StateMachine") as StateMachine
    assert_eq(StringName(sm.current_state.name), &"Idle")
    Input.action_press("move_right")
    await get_tree().physics_frame
    assert_eq(StringName(sm.current_state.name), &"Run")
    Input.action_release("move_right")
```

## Common pitfalls

- **Transitions during enter()**: don't call `change_state` from inside `enter()` — it can cause re-entry. Defer with `call_deferred`.
- **State node names must be unique** within the StateMachine — they're the dictionary keys.
- **`owner`** in a `State` script is the scene's owner (the entity), not the StateMachine. Useful for accessing siblings.
- **AnimationPlayer transitions**: prefer driving animations from `enter()` so re-entering a state replays the animation; otherwise use `AnimationTree` state machine.
