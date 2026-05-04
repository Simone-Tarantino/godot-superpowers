---
name: create-resource
description: Generate a custom Resource class for game data — Item, Ability, EnemyStats, DialogueLine, LevelConfig. Provides @export schema, validation, and one example .tres instance. Replaces Dictionary-literal data.
allowed-tools: Read, Write, Edit
argument-hint: <resource-name> [field:type ...]
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Create Resource

Generate a custom `Resource` class so designers (or a future you) can author data as `.tres` files in the editor instead of hardcoded `Dictionary` literals.

## Why Resources over Dictionaries

| Concern | `Dictionary` | Custom `Resource` |
|---------|--------------|-------------------|
| Type safety | none (Variant) | typed `@export` fields |
| Editor authoring | code only | Inspector with field hints |
| Validation | runtime checks | `@export_range`, `@export_enum`, etc. |
| Refactor rename | grep | rename in script, all `.tres` re-resolve |
| Save/load | fragile | first-class, `ResourceSaver.save` |
| Diff in git | unstructured | clean key=value text |

Use Dictionary only for **transient runtime payloads** (state machine state, signal arguments, network packets).

## Template — basic Resource

```gdscript
class_name {Name}
extends Resource

@export var id: StringName
@export var display_name: String
# add fields here
```

Save to `scripts/resources/{snake_case}.gd`. Then in the FileSystem dock right-click → **New Resource → {Name}** to author `.tres` instances under `resources/{plural}/`.

## Common templates

### Item

```gdscript
class_name Item
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var max_stack: int = 1
@export var value: int = 0
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: int = 0
@export var tags: Array[StringName] = []
@export var on_use: Script  ## script that defines a static use(actor: Node) -> void
```

### Ability / Spell

```gdscript
class_name Ability
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var cooldown: float = 1.0
@export var resource_cost: int = 0   ## mana / energy / stamina
@export_range(0.0, 50.0, 0.5) var range: float = 5.0
@export var damage: int = 0
@export var effect_scene: PackedScene
@export var sound: AudioStream
@export var animation_name: StringName = &""
@export var tags: Array[StringName] = []   ## "fire", "ranged", "channeled"
```

### EnemyStats

```gdscript
class_name EnemyStats
extends Resource

@export var id: StringName
@export var display_name: String
@export var sprite_frames: SpriteFrames
@export var max_health: int = 30
@export var damage: int = 5
@export var speed: float = 80.0
@export var attack_range: float = 30.0
@export var detect_range: float = 200.0
@export var xp_drop: int = 10
@export var loot_table: LootTable    ## another Resource
@export var ai_tree: PackedScene      ## behavior tree scene
```

### LootTable

```gdscript
class_name LootTable
extends Resource

@export var entries: Array[LootEntry] = []


func roll(rng: RandomNumberGenerator) -> Array[Item]:
    var out: Array[Item] = []
    for entry in entries:
        if rng.randf() < entry.chance:
            out.append(entry.item)
    return out


class LootEntry extends Resource:
    @export var item: Item
    @export_range(0.0, 1.0, 0.01) var chance: float = 0.5
    @export var min_count: int = 1
    @export var max_count: int = 1
```

### DialogueLine

```gdscript
class_name DialogueLine
extends Resource

@export var speaker: StringName
@export_multiline var text: String
@export var portrait: Texture2D
@export var audio: AudioStream
@export var choices: Array[DialogueChoice] = []
@export var next_id: StringName = &""    ## empty = end of conversation
@export var conditions: Dictionary[StringName, Variant] = {}
```

### LevelConfig

```gdscript
class_name LevelConfig
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var music: AudioStream
@export var ambience: AudioStream
@export_range(1, 10) var difficulty: int = 1
@export var enemy_pool: Array[EnemyStats] = []
@export var time_limit_seconds: float = 0.0   ## 0 = unlimited
@export var unlocks_on_complete: Array[StringName] = []
```

### CardData (turn-based / card games)

```gdscript
class_name CardData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var cost: int = 1
@export var attack: int = 0
@export var health: int = 1
@export var speed: int = 5
@export var card_type: StringName = &"unit"   ## "unit", "spell", "trap"
@export var placement: StringName = &"any"    ## "any", "own_side", "back_line"
@export var tags: Array[StringName] = []
@export_multiline var rules_text: String
@export var effect_script: Script
```

## `@export` annotation cheatsheet

| Annotation | Use |
|------------|-----|
| `@export var x: int` | Basic typed export |
| `@export_range(0, 100)` | Numeric slider with range |
| `@export_range(0.0, 1.0, 0.01)` | Float with step |
| `@export_enum("A", "B", "C")` | Picklist (stores int by default; add `:String` for string) |
| `@export_multiline var s: String` | Multi-line text editor |
| `@export_file("*.png")` | File picker filtered |
| `@export_dir` | Directory picker |
| `@export_node_path(NodeType)` | Typed node path picker |
| `@export_color_no_alpha` | Color without alpha slider |
| `@export_flags("Fire:1", "Ice:2", "Wind:4")` | Bit flags multi-select |
| `@export_storage` | Saved but not shown in editor |
| `@export_custom(...)` | Custom hint (advanced) |
| `@export_group("Combat")` | Group following exports |
| `@export_subgroup("Attack")` | Sub-group |
| `@export_category("Visual")` | Top-level category |

## Resource-with-methods

Resources can have logic, not just fields:

```gdscript
class_name Stat
extends Resource

@export var base: float = 10.0
@export var modifiers: Array[StatModifier] = []


func get_value() -> float:
    var value := base
    var add := 0.0
    var mult := 1.0
    for m in modifiers:
        match m.kind:
            StatModifier.Kind.FLAT: value += m.amount
            StatModifier.Kind.PERCENT_ADD: add += m.amount
            StatModifier.Kind.PERCENT_MULT: mult *= 1.0 + m.amount
    return (value + value * add) * mult


class StatModifier extends Resource:
    enum Kind { FLAT, PERCENT_ADD, PERCENT_MULT }
    @export var kind: Kind = Kind.FLAT
    @export var amount: float = 0.0
    @export var source: StringName = &""
```

## Common gotchas

- **Shared instances**: `load("res://x.tres")` returns the same Resource every call. If you mutate it (e.g. add modifiers to a Stat), you mutate it for everyone. Call `.duplicate(true)` for deep copy.
- **Inner classes** (`class X extends Resource`) work but their `.tres` files become hard to instantiate from the editor — prefer top-level `class_name`.
- **Resource references in arrays**: `@export var arr: Array[Item]` works; `Array[ItemSubclass]` does not (Godot stores the array as base class).
- **Circular references**: A holds B, B holds A — Godot detects cycles in 4.x but the file becomes hard to read. Prefer using IDs and resolving lazily.
- **Inspector reload**: editing the script while the editor has a `.tres` open can wipe values. Save scripts, close `.tres`, then re-open.

## Authoring `.tres` instances

1. FileSystem dock → right-click in `resources/items/` → **New Resource → Item**
2. Save as `iron_sword.tres`
3. Edit fields in Inspector
4. Reference from another resource or scene: drag `iron_sword.tres` into an `@export var weapon: Item` slot
