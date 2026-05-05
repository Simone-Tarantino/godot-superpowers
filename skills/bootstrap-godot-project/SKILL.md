---
name: bootstrap-godot-project
description: Scaffold a brand-new Godot 4.x project — create directory structure, base autoloads (EventBus, GameState, SceneManager, AudioManager, SaveManager), .gitignore, .gdignore, project.godot defaults, and a placeholder main scene. Use at the start of a new project.
allowed-tools: Read, Write, Edit, Bash, Glob
argument-hint: [project-name]
---

# Bootstrap Godot Project

Scaffold a clean Godot 4.x project layout. Run from the project root (where `project.godot` will live, or already lives).

## Steps

### 1. Directory structure

```
.
├── addons/
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   ├── sfx/
│   │   ├── ambience/
│   │   └── voice/
│   ├── fonts/
│   ├── sprites/
│   ├── textures/
│   ├── models/
│   └── ui/
├── autoload/
├── docs/
├── resources/
│   ├── items/
│   ├── abilities/
│   └── settings/
├── scenes/
│   ├── main/
│   ├── player/
│   ├── enemies/
│   ├── ui/
│   ├── components/      # Reusable component scenes (create-component skill)
│   └── levels/
├── scripts/
│   ├── components/      # HealthComponent, Hurtbox, Hitbox, etc. (create-component skill)
│   ├── state_machine/   # StateMachine + State base classes
│   ├── states/          # Concrete state classes (PlayerIdleState, ...) (create-state-machine skill)
│   ├── resources/       # Custom Resource scripts (Item, Ability, ...) (create-resource skill)
│   └── ui/              # UI controllers (input_remap_menu, options_menu, ...) (setup-input-map skill)
├── shaders/
└── test/
    ├── unit/
    ├── integration/
    ├── helpers/         # GUT helpers (gut-test-writer skill)
    └── fixtures/        # Test data (gut-test-writer skill)
```

### 2. `.gitignore`

```gitignore
# Godot 4+ specific ignores
.godot/
.import/
*.translation

# Build outputs
builds/
exports/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Secrets / signing
*.keystore
*.cer
*.mobileprovision
.env
.env.*
export_presets.cfg
```

`export_presets.cfg` listed because it often contains keystore paths and signing secrets. Commit a sanitized template `export_presets.cfg.example` instead.

### 3. `.gdignore` placement

Drop a file named `.gdignore` (zero bytes) inside any folder Godot must NOT import (docs, tools, raw asset sources). Example:

```
docs/.gdignore
tools/.gdignore
```

### 4. Base autoloads

Generate these in `autoload/` and register each in `project.godot` `[autoload]` section. The `create-autoload` skill handles a single autoload at a time; this skill creates the standard set in one shot.

#### `autoload/event_bus.gd`

```gdscript
extends Node
## Project-wide signal bus. Decouples unrelated systems.
## Only declare cross-scene events here. Local signals stay on their owning scene.
##
## Below: a generic core (always useful) + opt-in blocks for common genres.
## Delete any block your game does not need — keep this autoload focused.

## ── Core (lifecycle, scenes, score) ────────────────────────────────────
signal game_started
signal game_paused(paused: bool)
signal scene_transition_started(target_path: String)
signal scene_transition_finished
signal score_changed(new_score: int)
signal checkpoint_reached(checkpoint_id: StringName)
signal item_collected(item_id: StringName)

## ── Combat / actors (delete if your game has no combat / no enemies) ───
signal player_spawned(player: Node)
signal player_died
signal health_changed(node: Node, old_value: float, new_value: float)
signal enemy_killed(enemy: Node, source: Node)
signal attack_missed(attacker: Node, target: Node)

## ── Turn-based (used by genre-pack-turnbased; delete for real-time games) ─
signal player_turn_started(actor: Node)

## ── Camera / juice ─────────────────────────────────────────────────────
signal camera_shake_requested(magnitude: float, duration: float)
```

#### `autoload/game_state.gd`

```gdscript
extends Node
## Run-scoped global state. Score, current level, flags. Not persisted between sessions.
## For persisted data, see SaveManager.

var score: int = 0
var current_level: StringName = &""
var flags: Dictionary[StringName, Variant] = {}

func reset() -> void:
    score = 0
    current_level = &""
    flags.clear()
    EventBus.game_started.emit()

func set_flag(key: StringName, value: Variant) -> void:
    flags[key] = value

func get_flag(key: StringName, default: Variant = null) -> Variant:
    return flags.get(key, default)
```

#### `autoload/scene_manager.gd`

```gdscript
extends Node
## Scene transitions with optional fade.

const FADE_DURATION := 0.3

@onready var _fade_layer: CanvasLayer = _build_fade_layer()
@onready var _fade_rect: ColorRect = _fade_layer.get_child(0)

func change_to(scene_path: String) -> void:
    EventBus.scene_transition_started.emit(scene_path)
    await _fade_in()
    var packed := load(scene_path) as PackedScene
    if packed == null:
        push_error("Failed to load scene: %s" % scene_path)
        return
    get_tree().change_scene_to_packed(packed)
    await _fade_out()
    EventBus.scene_transition_finished.emit()

func change_to_packed(packed: PackedScene) -> void:
    EventBus.scene_transition_started.emit(packed.resource_path)
    await _fade_in()
    get_tree().change_scene_to_packed(packed)
    await _fade_out()
    EventBus.scene_transition_finished.emit()

func _fade_in() -> Signal:
    var tw := create_tween()
    tw.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
    return tw.finished

func _fade_out() -> Signal:
    var tw := create_tween()
    tw.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
    return tw.finished

func _build_fade_layer() -> CanvasLayer:
    var layer := CanvasLayer.new()
    layer.layer = 100
    var rect := ColorRect.new()
    rect.color = Color(0, 0, 0, 0)
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(rect)
    add_child(layer)
    return layer
```

#### `autoload/audio_manager.gd`

```gdscript
extends Node
## Pooled SFX playback + music crossfade. Bus volumes persist via ConfigFile at user://settings.cfg.

const SFX_POOL_SIZE := 16

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _music_target_db: float = -8.0

func _ready() -> void:
    for i in SFX_POOL_SIZE:
        var p := AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        _sfx_players.append(p)
    _music_a = _make_music_player()
    _music_b = _make_music_player()
    _active_music = _music_a

func play_sfx(stream: AudioStream, pitch_variation: float = 0.1, bus: StringName = &"SFX") -> void:
    if stream == null:
        return
    var p := _get_free_sfx_player()
    if p == null:
        return
    p.stream = stream
    p.bus = bus
    p.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
    p.play()

func crossfade_music(stream: AudioStream, duration: float = 1.5) -> void:
    var fading := _active_music
    var rising := _music_b if _active_music == _music_a else _music_a
    rising.stream = stream
    rising.volume_db = -80.0
    rising.play()
    var tw := create_tween().set_parallel()
    tw.tween_property(fading, "volume_db", -80.0, duration)
    tw.tween_property(rising, "volume_db", _music_target_db, duration)
    tw.chain().tween_callback(fading.stop)
    _active_music = rising

func set_bus_volume(bus_name: StringName, db: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx >= 0:
        AudioServer.set_bus_volume_db(idx, db)

func _get_free_sfx_player() -> AudioStreamPlayer:
    for p in _sfx_players:
        if not p.playing:
            return p
    return null

func _make_music_player() -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.bus = "Music"
    p.volume_db = -80.0
    add_child(p)
    return p
```

#### `autoload/save_manager.gd`

```gdscript
extends Node
## Resource-based save/load. Walks the "persist" group, calls save_data() / load_data().

const SAVE_DIR := "user://saves/"

func save_game(slot: int) -> Error:
    DirAccess.make_dir_recursive_absolute(SAVE_DIR)
    var data := SaveData.new()
    data.timestamp = Time.get_unix_time_from_system()
    for node in get_tree().get_nodes_in_group("persist"):
        if node.has_method("save_data"):
            data.entries[node.get_path()] = node.save_data()
    return ResourceSaver.save(data, _path_for(slot))

func load_game(slot: int) -> Error:
    var path := _path_for(slot)
    if not FileAccess.file_exists(path):
        return ERR_FILE_NOT_FOUND
    var data := load(path) as SaveData
    if data == null:
        return ERR_PARSE_ERROR
    for node in get_tree().get_nodes_in_group("persist"):
        var entry: Variant = data.entries.get(node.get_path())
        if entry != null and node.has_method("load_data"):
            node.load_data(entry)
    return OK

func has_save(slot: int) -> bool:
    return FileAccess.file_exists(_path_for(slot))

func _path_for(slot: int) -> String:
    return "%sslot_%d.tres" % [SAVE_DIR, slot]
```

Plus `scripts/resources/save_data.gd` (canonical shape — the `setup-save-system` skill expands the SaveManager around this):

```gdscript
class_name SaveData
extends Resource
## Top-level save container. One file per slot. Bump `version` when fields change.

@export var version: int = 1
@export var timestamp: int = 0
@export var play_time_seconds: float = 0.0
@export var current_scene: String = ""
@export var entries: Dictionary[NodePath, Variant] = {}
```

### 5. Register autoloads in `project.godot`

```ini
[autoload]
EventBus="*res://autoload/event_bus.gd"
GameState="*res://autoload/game_state.gd"
SceneManager="*res://autoload/scene_manager.gd"
AudioManager="*res://autoload/audio_manager.gd"
SaveManager="*res://autoload/save_manager.gd"
```

The leading `*` makes the singleton globally accessible by name. Order matters: dependencies should appear before their dependents.

### 6. Project settings essentials

**Detect installed Godot version first** — the `config/features` line MUST match the engine that will open the project, otherwise Godot warns about a version mismatch on first load. Detect at scaffold time:

```bash
# Get the major.minor of the locally installed Godot (e.g. "4.5")
godot_version=$(godot --version 2>/dev/null | head -1 | grep -oE '^[0-9]+\.[0-9]+')
echo "$godot_version"
```

If `godot --version` is unavailable (CI / fresh box), fall back to the **latest stable** Godot 4.x release per the [Godot download page](https://godotengine.org/download/) — never hardcode an older version. Verify against [docs.godotengine.org/en/stable](https://docs.godotengine.org/en/stable/) which always reflects the current stable.

Add to `project.godot` (substitute `$godot_version` with the detected/latest value):

```ini
[application]
config/name="MyGame"
## Pick the rendering backend that matches the target:
##   "Forward Plus"   — desktop, high-end (default for new desktop games)
##   "Mobile"         — mobile + low-end desktop (lighter shading model)
##   "Compatibility"  — Web (HTML5) and very old GPUs (GLES3-equivalent)
config/features=PackedStringArray("$godot_version", "Forward Plus")
run/main_scene="res://scenes/main/main.tscn"

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[input]
; populated via setup-input-map skill

[layer_names]
; populated via setup-collision-layers skill

[rendering]
textures/canvas_textures/default_texture_filter=0  ; pixel art (0=Nearest); set 1=Linear for smooth art
```

### 7. Placeholder main scene

`scenes/main/main.tscn` — single `Node` root with a script `main.gd`:

```gdscript
extends Node

func _ready() -> void:
    print("Project bootstrapped. Replace scenes/main/main.tscn with your real entry point.")
```

### 8. Recommended addons

Suggest installing (via Asset Library or Git submodule):
- **GUT** or **GdUnit4** — testing
- **Phantom Camera** — camera control rig (2D + 3D)
- **Beehave** or **LimboAI** — behavior trees / state machines
- **Dialogic** or **Dialogue Manager** — dialogue
- **gdtoolkit** (Python, not addon) — `gdformat`, `gdlint`

### 9. Final checklist

- [ ] Open project once in Godot to populate `.godot/` cache
- [ ] Verify all autoloads load without errors
- [ ] Add a `README.md` (use the `update-docs` skill)
- [ ] Initialize git: `git init && git add . && git commit -m "Initial bootstrap"`
- [ ] Configure collision layers (`setup-collision-layers` skill)
- [ ] Configure input map (`setup-input-map` skill)
