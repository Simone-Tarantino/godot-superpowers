---
name: create-autoload
description: Add a new singleton autoload — create the script in autoload/, register it in project.godot's [autoload] section, and provide a usage snippet. Use for one-off autoloads; for the standard set use bootstrap-godot-project instead.
allowed-tools: Read, Write, Edit
argument-hint: <name> [extends-class]
---

# Create Autoload

Generate a single autoload singleton. For the canonical starter set (EventBus, GameState, SceneManager, AudioManager, SaveManager) use the `bootstrap-godot-project` skill.

## Steps

### 1. Create the script

`autoload/<snake_case_name>.gd`:

```gdscript
extends Node
## {OneLinePurpose}.
## Registered as autoload "{PascalCaseName}". Access globally via {PascalCaseName}.

# signals
# enums
# constants
# vars

func _ready() -> void:
    pass
```

`extends Node` is the safe default. Use `Node2D` / `Node3D` only if the autoload needs a transform (rare). `Object` won't work — autoloads must be `Node`.

### 2. Register in `project.godot`

Add under `[autoload]` (create the section if missing):

```ini
[autoload]
{PascalCaseName}="*res://autoload/{snake_case_name}.gd"
```

The leading `*` enables the singleton — without it, the script just gets instantiated as a child of the root node, NOT exposed by name.

**Order matters**: an autoload that depends on another must appear after it. Example: `SceneManager` depends on `EventBus` → list `EventBus` first.

### 3. Reload project

Either restart Godot or open `Project Settings → Globals → Autoload` to see the entry. The editor exposes the autoload to scripts only after registration is loaded.

### 4. Use it

```gdscript
# anywhere in any script
SaveManager.save_game(0)
EventBus.player_died.emit()
```

## Decision rules

### When to autoload

✅ Cross-scene state that must persist across scene changes (current run data, audio bus volumes, save slot)
✅ Cross-scene event hub (`EventBus`)
✅ Single-instance services (`AudioManager`, `SaveManager`, `SceneManager`)
✅ Settings / config that any scene reads

### When NOT to autoload

❌ Anything tied to a specific scene's lifecycle (player, level)
❌ Anything you might want multiple of (camera rig, AI brain)
❌ Heavy `_process` work that runs even when irrelevant
❌ Things that should be `Resource` instead (pure data)

### Alternatives

| Alternative | When |
|-------------|------|
| Group + `get_tree().call_group()` | Many-to-many broadcasts (alert all enemies) |
| Static class (`class_name X extends RefCounted`) | Pure utility functions, no state |
| Resource singleton via preload | Shared read-only data (curves, constants) |
| Service locator on a non-autoload root node | Tested apps where DI is preferred |

## Common autoload templates

### Settings manager

```gdscript
extends Node
## Persistent player settings (volume, resolution, language). ConfigFile-backed.

const PATH := "user://settings.cfg"

signal settings_changed

var _cfg := ConfigFile.new()

func _ready() -> void:
    if _cfg.load(PATH) != OK:
        _set_defaults()
    _apply()

func get_value(section: StringName, key: StringName, default: Variant) -> Variant:
    return _cfg.get_value(section, key, default)

func set_value(section: StringName, key: StringName, value: Variant) -> void:
    _cfg.set_value(section, key, value)
    _cfg.save(PATH)
    settings_changed.emit()
    _apply()

func _set_defaults() -> void:
    _cfg.set_value("audio", "master_db", 0.0)
    _cfg.set_value("audio", "music_db", -8.0)
    _cfg.set_value("audio", "sfx_db", -3.0)
    _cfg.set_value("video", "fullscreen", false)
    _cfg.set_value("video", "vsync", true)
    _cfg.save(PATH)

func _apply() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), get_value("audio", "master_db", 0.0))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), get_value("audio", "music_db", -8.0))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), get_value("audio", "sfx_db", -3.0))
    var fs: bool = get_value("video", "fullscreen", false)
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
    var vs: bool = get_value("video", "vsync", true)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vs else DisplayServer.VSYNC_DISABLED)
```

### Input remap

The `setup-input-map` skill configures `project.godot` `[input]` and generates a runtime remap menu (`scenes/ui/input_remap_menu.tscn`). It does **not** create an InputManager autoload — Godot's global `Input` and `InputMap` singletons cover that. Wrap them in an autoload only if you need cross-cutting behavior like recording inputs for replays or input buffering across scenes.

### Random / RNG (seeded for replays)

```gdscript
extends Node
## Deterministic RNG. Seed once, derive sub-streams for separate systems.

var _rng := RandomNumberGenerator.new()
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}

func _ready() -> void:
    _rng.randomize()

func seed_run(s: int) -> void:
    _rng.seed = s
    _streams.clear()

func stream(name: StringName) -> RandomNumberGenerator:
    if not _streams.has(name):
        var s := RandomNumberGenerator.new()
        s.seed = hash([_rng.seed, name])
        _streams[name] = s
    return _streams[name]
```

Use `RNG.stream(&"loot").randf()` so loot rolls don't desync from combat rolls.
