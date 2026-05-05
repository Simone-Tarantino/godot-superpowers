---
name: setup-save-system
description: Set up a Resource-based save/load system for Godot 4.x — SaveManager autoload, SaveData Resource, persist group convention, save slots. Handles Vector2, Color, Resource refs, custom classes (which JSON cannot).
allowed-tools: Read, Write, Edit
---

# Setup Save System

Resource-backed save system. Survives reboots, handles typed data (Vector2, Color, Resources, custom classes), and uses a **group + method** convention so each persistable node owns its own serialization.

## Why Resource over JSON

| Format | Vector2 / Color | Resource refs | Custom classes | Human-readable |
|--------|-----------------|---------------|----------------|----------------|
| `JSON` | ❌ string | ❌ | ❌ | ✅ |
| `ConfigFile` | ✅ | ❌ (path only) | ❌ | ✅ |
| `Resource` (`.tres`) | ✅ | ✅ | ✅ | ✅ (text) |
| `Resource` (`.res`) | ✅ | ✅ | ✅ | ❌ (binary, faster) |
| `FileAccess.store_var` | ✅ | ❌ (path only) | ❌ | ❌ |

Use **`Resource`** for save data. JSON / ConfigFile are fine for **settings** (which are simple key-value).

## Files to create

### `resources/save_data.gd`

```gdscript
class_name SaveData
extends Resource
## Top-level save container. One file per slot.

@export var version: int = 1
@export var timestamp: int = 0
@export var play_time_seconds: float = 0.0
@export var current_scene: String = ""
@export var entries: Dictionary[NodePath, Variant] = {}
```

Bumping `version` lets you migrate old saves in `SaveManager.load_game`.

### `autoload/save_manager.gd`

```gdscript
extends Node
## Resource-based save/load. Walks the "persist" group and calls
## save_data() / load_data() on each node. Per-node payloads are stored
## by NodePath in the SaveData.entries dictionary.

const SAVE_DIR := "user://saves/"
const VERSION := 1

signal save_started(slot: int)
signal save_finished(slot: int, ok: bool)
signal load_started(slot: int)
signal load_finished(slot: int, ok: bool)

# Cumulative play time across sessions. Previous form `Time.get_ticks_msec() / 1000.0`
# resets to engine-boot every save, throwing away prior sessions.
var _play_time_accum: float = 0.0
var _session_start_msec: int = 0

func _ready() -> void:
    _session_start_msec = Time.get_ticks_msec()

func save_game(slot: int) -> bool:
    save_started.emit(slot)
    DirAccess.make_dir_recursive_absolute(SAVE_DIR)
    var data := SaveData.new()
    data.version = VERSION
    data.timestamp = Time.get_unix_time_from_system()
    var now_msec: int = Time.get_ticks_msec()
    _play_time_accum += float(now_msec - _session_start_msec) / 1000.0
    _session_start_msec = now_msec
    data.play_time_seconds = _play_time_accum
    data.current_scene = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
    for node in get_tree().get_nodes_in_group("persist"):
        if node.has_method("save_data"):
            data.entries[node.get_path()] = node.save_data()
    var err := ResourceSaver.save(data, _path_for(slot))
    var ok := err == OK
    save_finished.emit(slot, ok)
    return ok

func load_game(slot: int) -> bool:
    load_started.emit(slot)
    var path := _path_for(slot)
    if not FileAccess.file_exists(path):
        load_finished.emit(slot, false)
        return false
    var data := load(path) as SaveData
    if data == null:
        load_finished.emit(slot, false)
        return false
    if data.version != VERSION:
        data = _migrate(data)
    _play_time_accum = data.play_time_seconds
    _session_start_msec = Time.get_ticks_msec()
    if data.current_scene != "" and data.current_scene != get_tree().current_scene.scene_file_path:
        await get_tree().create_timer(0.0).timeout  # let frame settle
        # Dynamic path from save → load() + change_scene_to_packed(); use preload() for static paths.
        var packed: PackedScene = load(data.current_scene) as PackedScene
        get_tree().change_scene_to_packed(packed)
        await get_tree().process_frame
    for node in get_tree().get_nodes_in_group("persist"):
        var entry: Variant = data.entries.get(node.get_path())
        if entry != null and node.has_method("load_data"):
            node.load_data(entry)
    load_finished.emit(slot, true)
    return true

func has_save(slot: int) -> bool:
    return FileAccess.file_exists(_path_for(slot))

func delete_save(slot: int) -> bool:
    var path := _path_for(slot)
    if not FileAccess.file_exists(path):
        return false
    return DirAccess.remove_absolute(path) == OK

func get_save_info(slot: int) -> SaveData:
    var path := _path_for(slot)
    if not FileAccess.file_exists(path):
        return null
    return load(path) as SaveData

func _path_for(slot: int) -> String:
    return "%sslot_%d.tres" % [SAVE_DIR, slot]

func _migrate(data: SaveData) -> SaveData:
    # add migrations here as VERSION bumps
    data.version = VERSION
    return data
```

Register `SaveManager` as autoload (use the `create-autoload` skill).

## Per-node convention

Any node that needs persistence:

1. Joins the `persist` group: `add_to_group("persist")` in `_ready()` (or check the group in the editor)
2. Implements `save_data() -> Variant`: returns plain data (Dictionary, Resource, primitive)
3. Implements `load_data(payload: Variant) -> void`: applies the payload

```gdscript
class_name Player
extends CharacterBody2D

func _ready() -> void:
    add_to_group("persist")

func save_data() -> Dictionary:
    return {
        "position": position,
        "current_health": $HealthComponent.current_health,
        "inventory": $Inventory.serialize(),
    }

func load_data(payload: Dictionary) -> void:
    position = payload.get("position", Vector2.ZERO)
    $HealthComponent.current_health = payload.get("current_health", $HealthComponent.max_health)
    $Inventory.deserialize(payload.get("inventory", {}))
```

For complex sub-systems (like `Inventory`), expose `serialize()` / `deserialize()` on the component itself and have the parent forward to it.

## Save slots UI sketch

```
SaveSlotMenu (Control)
├── SlotList (VBoxContainer)
│   ├── SlotRow (HBoxContainer) × N
│   │   ├── SlotLabel ("Slot 1 — 2026-05-04 12:34, 3h 12m")
│   │   ├── LoadButton
│   │   └── DeleteButton
│   └── (empty slot row shows "New Game")
└── BackButton
```

`SlotRow` queries `SaveManager.get_save_info(slot)` to populate label.

## Autosave hooks

```gdscript
# in some controller node
func _ready() -> void:
    EventBus.checkpoint_reached.connect(_on_checkpoint)

func _on_checkpoint() -> void:
    SaveManager.save_game(0)  # slot 0 reserved for autosave
```

For continuous autosave, run on a `Timer` (every 2–5 minutes) but only if game state has changed since the last save (to avoid disk churn).

## Caveats

- **Don't store `Node` references.** Store `NodePath` if needed; resolve via `get_node(path)` on load.
- **Don't store packed scenes inline.** Store the scene's `resource_path` (`String`) and reload via `load(path) as PackedScene`.
- **Resources are reference-counted.** If you want a *copy*, call `.duplicate(true)` (deep) before saving.
- **`Time.get_unix_time_from_system()`** is locale-aware; store UTC if you ship globally.
- **Test save/load on a fresh machine** before shipping. `user://` resolves differently per OS.

## See also

- [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) — official docs
- [Resource](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)
