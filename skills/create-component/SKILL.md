---
name: create-component
description: Generate reusable component scenes and scripts — HealthComponent, HurtboxComponent, HitboxComponent, MoveComponent, InteractableComponent, InventoryComponent. Composition-first, signal-driven.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: <component-type> [target-2d | target-3d]
---

# Create Component

Generate a reusable component as a scene + script. Composition pattern: drop the component as a child of the entity that should "have" the behavior.

Save scenes to `scenes/components/<name>.tscn` and scripts to `scripts/components/<name>.gd`.

## HealthComponent

Decoupled HP from the entity. Any entity that can take damage drops one in.

`scripts/components/health_component.gd`:

```gdscript
class_name HealthComponent
extends Node

signal health_changed(old: int, new: int)
signal died
signal revived

@export var max_health: int = 100
@export var invulnerable: bool = false

var current_health: int

func _ready() -> void:
    current_health = max_health

func take_damage(amount: int, _source: Node = null) -> void:
    if invulnerable or current_health <= 0:
        return
    var prev := current_health
    current_health = maxi(0, current_health - amount)
    if current_health != prev:
        health_changed.emit(prev, current_health)
    if current_health == 0:
        died.emit()

func heal(amount: int) -> void:
    if current_health <= 0:
        return
    var prev := current_health
    current_health = mini(max_health, current_health + amount)
    if current_health != prev:
        health_changed.emit(prev, current_health)

func revive(amount: int = -1) -> void:
    var was_dead := current_health == 0
    current_health = max_health if amount < 0 else mini(max_health, amount)
    if was_dead:
        revived.emit()
    health_changed.emit(0, current_health)

func get_health_ratio() -> float:
    return float(current_health) / float(max_health) if max_health > 0 else 0.0
```

`scenes/components/health_component.tscn`: `Node` root, attach the script.

## HurtboxComponent (2D and 3D variants)

Receives damage. Attach as child Area2D / Area3D with a CollisionShape sibling.

`scripts/components/hurtbox_component_2d.gd`:

```gdscript
class_name HurtboxComponent2D
extends Area2D
## Receives damage. Forwards to a HealthComponent reference.

@export var health_component: HealthComponent
@export var damage_modifier: float = 1.0  ## e.g. 0.5 = takes half damage

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if area is HitboxComponent2D and health_component:
        var dmg := int(area.damage * damage_modifier)
        health_component.take_damage(dmg, area.owner)
```

`scripts/components/hurtbox_component_3d.gd`: same but `Area3D` / `HitboxComponent3D`.

## HitboxComponent (2D and 3D)

Deals damage when its area overlaps an opposing hurtbox.

```gdscript
class_name HitboxComponent2D
extends Area2D

@export var damage: int = 10
@export var knockback: float = 200.0
@export var disabled_on_start: bool = false

func _ready() -> void:
    monitoring = false  # off by default; enable during attacks
    if disabled_on_start:
        return
    enable()

func enable() -> void:
    monitoring = true

func disable() -> void:
    monitoring = false
```

Pair Hurtbox + Hitbox with proper collision layers (see `setup-collision-layers`):
- HurtboxComponent on the receiver, layer = `PlayerHurtbox` or `EnemyHurtbox`
- HitboxComponent on the dealer, layer = `PlayerHitbox` or `EnemyHitbox`, mask = opposing hurtbox layer

## MoveComponent (genre-agnostic skeleton)

This foundation skill ships only the **generic** MoveComponent — a thin `CharacterBody2D` driver that owns horizontal velocity and the `move_and_slide()` call. Genre-specific behavior (gravity tuning, jump shaping, coyote / buffer windows, dashes, wall jumps, top-down 8-direction movement, 3D camera-relative motion) lives in the matching genre pack.

```gdscript
class_name MoveComponent2D
extends Node
## Genre-agnostic 2D mover. Drives a CharacterBody2D parent's horizontal velocity.
## Vertical motion (gravity, jump, fall behavior) is intentionally NOT handled here —
## a genre pack (or your own subclass) layers it on top via `physics_step`.

@export var max_speed: float = 250.0
@export var acceleration: float = 1500.0
@export var friction: float = 1500.0

var body: CharacterBody2D

func _ready() -> void:
    body = get_parent() as CharacterBody2D
    assert(body, "MoveComponent2D parent must be CharacterBody2D")

func physics_step(_delta: float, input_x: float) -> void:
    if absf(input_x) > 0.0:
        body.velocity.x = move_toward(body.velocity.x, input_x * max_speed, acceleration * _delta)
    else:
        body.velocity.x = move_toward(body.velocity.x, 0.0, friction * _delta)
    body.move_and_slide()
```

For 3D, swap `CharacterBody2D` → `CharacterBody3D` and use `Vector3` velocity.

### Genre specializations

| Genre | Skill | Adds on top of MoveComponent |
|---|---|---|
| 2D platformer | `genre-pack-platformer` | gravity + variable jump + coyote time + jump buffer + wall jump / dash |
| 2D top-down | `genre-pack-topdown` | 8-direction movement, no gravity, optional A* path follow |
| 3D action | `genre-pack-3d-action` | camera-relative movement, SpringArm follow, lock-on facing |
| Turn-based | `genre-pack-turnbased` | tile-snap movement, action-queue integration |

Pick exactly one genre pack per project (per the `writing-game-plan` sequencing rules) before tuning player feel.

## InteractableComponent

Marks an entity as interactable. The player checks for nearby `InteractableComponent` and calls `interact()`.

```gdscript
class_name InteractableComponent
extends Area2D

signal interacted(by: Node)

@export var prompt: String = "Interact"
@export var one_shot: bool = false

var _consumed: bool = false

func interact(by: Node) -> void:
    if _consumed:
        return
    interacted.emit(by)
    if one_shot:
        _consumed = true
```

Player code:

```gdscript
func _try_interact() -> void:
    var bodies := $InteractRange.get_overlapping_areas()
    for area in bodies:
        if area is InteractableComponent:
            area.interact(self)
            return
```

## InventoryComponent

```gdscript
class_name InventoryComponent
extends Node

signal item_added(item: Item, count: int)
signal item_removed(item: Item, count: int)
signal inventory_changed

@export var max_slots: int = 20

var _slots: Array[Dictionary] = []  # each: {"item": Item, "count": int}

func add(item: Item, count: int = 1) -> int:
    var remaining := count
    if item.max_stack > 1:
        for slot in _slots:
            if slot.item == item and slot.count < item.max_stack:
                var add_count := mini(item.max_stack - slot.count, remaining)
                slot.count += add_count
                remaining -= add_count
                if remaining == 0:
                    break
    while remaining > 0 and _slots.size() < max_slots:
        var add_count := mini(item.max_stack, remaining) if item.max_stack > 0 else remaining
        _slots.append({"item": item, "count": add_count})
        remaining -= add_count
    if remaining < count:
        item_added.emit(item, count - remaining)
        inventory_changed.emit()
    return count - remaining

func remove(item: Item, count: int = 1) -> int:
    var remaining := count
    for i in range(_slots.size() - 1, -1, -1):
        if _slots[i].item != item:
            continue
        var taken := mini(_slots[i].count, remaining)
        _slots[i].count -= taken
        remaining -= taken
        if _slots[i].count == 0:
            _slots.remove_at(i)
        if remaining == 0:
            break
    if remaining < count:
        item_removed.emit(item, count - remaining)
        inventory_changed.emit()
    return count - remaining

func has(item: Item, count: int = 1) -> bool:
    var total := 0
    for slot in _slots:
        if slot.item == item:
            total += slot.count
            if total >= count:
                return true
    return false
```

`Item` is a custom Resource — see `create-resource` skill.

## Composition example

Player scene:

```
Player (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── Hurtbox (HurtboxComponent2D)
│   └── CollisionShape2D
├── Hitbox (HitboxComponent2D)         -> enabled during attack states
│   └── CollisionShape2D
├── HealthComponent
├── MoveComponent                      -> generic 2D mover (this skill); a genre pack may swap it
├── InventoryComponent
└── StateMachine                       -> states are project- and genre-specific; a platformer
    ├── Idle                              would add Jump / Fall / WallSlide, a top-down would
    └── Run                               add Aim / Roll, etc. — see the matching genre pack.
```

Player script wires components in `_ready`:

```gdscript
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent2D = $Hurtbox
@onready var _move: MoveComponent2D = $MoveComponent

func _ready() -> void:
    _hurtbox.health_component = _health
    _health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
    # Genre-agnostic input drive. A genre pack will add gravity, jump, dash, etc.
    var input_x := Input.get_axis("move_left", "move_right")
    _move.physics_step(delta, input_x)
```

## Notes

- Component nodes own **one** concern. Don't bundle health + inventory into one node.
- Components communicate via signals or direct references injected at `_ready` — no autoload coupling.
- For state-bearing components (HealthComponent), implement `save_data()` / `load_data()` if the parent is in `persist` group.
