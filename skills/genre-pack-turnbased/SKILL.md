---
name: genre-pack-turnbased
description: Turn-based / card / tactical pack — TurnManager autoload, Action queue with deterministic resolution, initiative ordering, action point system, replay-friendly RNG. Suitable for tactics RPG / card games / roguelikes.
allowed-tools: Read, Write, Edit
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Genre Pack: Turn-Based

Patterns for turn-based games — works for tactics RPGs, card games, roguelikes, and grid-based puzzlers. Designed for **deterministic resolution** so games are replay-friendly and netcode-friendly.

## Core idea

- An **Actor** is anything that takes turns (player, enemy, summon).
- The **TurnManager** orders actors by initiative and yields control to each in turn.
- Actors **submit Actions**; Actions get **resolved deterministically**.
- All randomness goes through a **seeded RNG** so the same input → same output.

## TurnManager

`autoload/turn_manager.gd`:

```gdscript
extends Node
## Round-based turn manager. Actors are ordered by initiative each round.
## Emits signals for UI; calls `take_turn()` on each Actor and awaits completion.

signal round_started(round_num: int)
signal round_ended(round_num: int)
signal turn_started(actor: Actor)
signal turn_ended(actor: Actor)
signal battle_ended(winner_team: StringName)

var actors: Array[Actor] = []
var current_round: int = 0
var current_actor_index: int = 0
var battle_running: bool = false


func start_battle(participants: Array[Actor]) -> void:
    actors = participants
    current_round = 0
    battle_running = true
    _next_round()


func _next_round() -> void:
    if not battle_running:
        return
    current_round += 1
    actors.sort_custom(func(a, b): return a.initiative > b.initiative)
    round_started.emit(current_round)
    current_actor_index = -1
    _next_turn()


func _next_turn() -> void:
    if not battle_running:
        return
    current_actor_index += 1
    if current_actor_index >= actors.size():
        round_ended.emit(current_round)
        _check_victory()
        if battle_running:
            _next_round()
        return
    var actor := actors[current_actor_index]
    if not actor.is_alive():
        _next_turn()
        return
    turn_started.emit(actor)
    await actor.take_turn()
    turn_ended.emit(actor)
    _next_turn()


func _check_victory() -> void:
    var teams: Dictionary[StringName, int] = {}
    for a in actors:
        if a.is_alive():
            teams[a.team] = teams.get(a.team, 0) + 1
    if teams.size() <= 1:
        battle_running = false
        var winner: StringName = teams.keys()[0] if teams.size() == 1 else &"draw"
        battle_ended.emit(winner)


func end_battle() -> void:
    battle_running = false
```

## Actor base

`scripts/turnbased/actor.gd`:

```gdscript
class_name Actor
extends Node

signal action_taken(action: Action)

@export var team: StringName = &"player"
@export var initiative: int = 5
@export var max_action_points: int = 3

var current_health: int = 0
var max_health: int = 0
var action_points: int = 0


func start_round() -> void:
    action_points = max_action_points


func take_turn() -> void:
    push_error("Subclass Actor and override take_turn()")


func is_alive() -> bool:
    return current_health > 0
```

## PlayerActor — waits for input

```gdscript
class_name PlayerActor
extends Actor

signal _turn_finished


func take_turn() -> void:
    start_round()
    EventBus.player_turn_started.emit(self)
    await _turn_finished


func submit_action(action: Action) -> void:
    if action.cost > action_points:
        return
    if not action.is_valid(self):
        return
    action_points -= action.cost
    var resolver := ActionResolver.new()
    resolver.resolve(action, self)
    action_taken.emit(action)
    if action_points <= 0:
        _turn_finished.emit()


func end_turn() -> void:
    _turn_finished.emit()
```

UI calls `submit_action(MoveAction.new(...))` and `end_turn()`.

## EnemyActor — AI selects and resolves immediately

```gdscript
class_name EnemyActor
extends Actor

@export var ai_brain: EnemyBrain   ## a Resource


func take_turn() -> void:
    start_round()
    while action_points > 0:
        var chosen: Action = ai_brain.choose_action(self)
        if chosen == null:
            break
        action_points -= chosen.cost
        var resolver := ActionResolver.new()
        resolver.resolve(chosen, self)
        action_taken.emit(chosen)
        await get_tree().create_timer(0.4).timeout   # pacing
```

## Action — Resource for serialization / replay

```gdscript
class_name Action
extends Resource

@export var name: StringName
@export var cost: int = 1


func is_valid(_actor: Actor) -> bool:
    return true


## Override in subclasses
func describe() -> String:
    return name
```

### MoveAction

```gdscript
class_name MoveAction
extends Action

@export var target_cell: Vector2i


func is_valid(actor: Actor) -> bool:
    return Battlefield.is_cell_walkable(target_cell)
```

### AttackAction

```gdscript
class_name AttackAction
extends Action

@export var target: Actor
@export var damage: int = 5
@export var hit_chance: float = 0.85


func is_valid(_actor: Actor) -> bool:
    return target != null and target.is_alive()
```

### ActionResolver

`scripts/turnbased/action_resolver.gd`:

```gdscript
class_name ActionResolver
extends RefCounted


func resolve(action: Action, actor: Actor) -> void:
    if action is MoveAction:
        actor.global_position = Battlefield.cell_to_world(action.target_cell)
    elif action is AttackAction:
        if RNG.stream(&"combat").randf() <= action.hit_chance:
            action.target.current_health -= action.damage
            if not action.target.is_alive():
                EventBus.enemy_killed.emit(action.target, actor)
        else:
            EventBus.attack_missed.emit(actor, action.target)
    # ... extend per action type
```

## Deterministic RNG (replay-friendly)

`autoload/rng.gd`:

```gdscript
extends Node
## Seeded RNG with named sub-streams. Same seed + same Action sequence = same outcome.

var _seed: int = 0
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func seed_run(s: int) -> void:
    _seed = s
    _streams.clear()


func stream(name: StringName) -> RandomNumberGenerator:
    if not _streams.has(name):
        var rng := RandomNumberGenerator.new()
        rng.seed = hash([_seed, name])
        _streams[name] = rng
    return _streams[name]
```

Use `RNG.stream(&"combat").randf()` so loot rolls don't desync from combat rolls when you replay.

## Card game variant

For card games, swap "Action" for "Card":

```gdscript
class_name CardData
extends Resource

@export var name: StringName
@export var cost: int = 1
@export var attack: int = 0
@export var health: int = 1
@export var card_type: StringName = &"unit"     ## "unit", "spell", "trap"
@export var placement: StringName = &"any"      ## "any", "own_side", "back_line"
@export var rules_text: String
@export var on_play: Script   ## script with `static func play(card: Card, owner: Actor) -> void`
```

Phase-based turn (Placement → Reveal → Resolve):

```gdscript
class_name CardTurnManager
extends Node

enum Phase { PLACEMENT, REVEAL, RESOLVE }
signal phase_changed(p: Phase)

var phase: Phase = Phase.PLACEMENT


func advance_phase() -> void:
    phase = (phase + 1) % Phase.size() as Phase
    phase_changed.emit(phase)
```

## Grid battlefield

For tile-based tactics:

```gdscript
class_name Battlefield
extends Node

const CELL_SIZE := Vector2(64, 64)

static var instance: Battlefield


func _enter_tree() -> void:
    instance = self


static func cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(cell) * CELL_SIZE + CELL_SIZE / 2.0


static func world_to_cell(world: Vector2) -> Vector2i:
    return Vector2i((world / CELL_SIZE).floor())


static func is_cell_walkable(cell: Vector2i) -> bool:
    # check tilemap, occupied actors, etc.
    return true
```

For 3D tactics, swap `Vector2`/`Vector2i` for `Vector3`/`Vector3i` and use `GridMap`.

## Initiative variants

| Style | How |
|-------|-----|
| **Round-robin** (D&D) | Sort by initiative once at battle start |
| **Round-by-round** (most JRPGs) | Re-sort every round |
| **Active time battle** (FF) | Each actor has a charging gauge; act when full |
| **Action point** (XCOM) | Each actor has 2-3 AP per turn; spend on movement / actions |
| **Speed-based** | Faster actors act more often within a round |

This pack supports round-robin and round-by-round out of the box. ATB is a small rewrite of `_next_turn` to advance gauges.

## UI hooks

EventBus signals to wire up in HUD:

- `turn_started(actor)` — highlight whose turn it is
- `turn_ended(actor)` — animate end-of-turn FX
- `action_taken(action)` — animate action result
- `phase_changed(phase)` — show "Placement Phase" banner
- `battle_ended(winner_team)` — show victory / defeat screen
