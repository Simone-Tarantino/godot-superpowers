---
name: sfx-generator
description: Generate SFX, music, and ambience for a Godot project — using ElevenLabs MCP if available, otherwise suggest free CC0 sources. Enforces format conventions (.wav for SFX, .ogg for music), naming, bus layout, and AudioManager integration.
allowed-tools: Read, Write, Bash, Glob, mcp__elevenlabs__*
argument-hint: <sound-or-music-description>
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# SFX & Music Generator

## Format rules (Godot 4.x)

| Use case | Format | Reason |
|----------|--------|--------|
| Short SFX (< 5s) | `.wav` | Decompressed, sample-accurate, low CPU |
| Music | `.ogg` Vorbis | Compressed, streamable, lossy-but-fine |
| Ambience loops | `.ogg` Vorbis | Same as music |
| Voice lines | `.ogg` Vorbis | Compressed, acceptable for speech |

**Never `.mp3`**: licensing baggage and worse looping than `.ogg`.

## Directory layout

```
assets/audio/
├── music/
│   ├── menu_theme.ogg
│   ├── battle_calm.ogg
│   └── boss.ogg
├── sfx/
│   ├── player/
│   ├── enemy/
│   ├── ui/
│   ├── combat/
│   ├── world/
│   └── pickup/
├── ambience/
│   ├── forest_day.ogg
│   └── cave.ogg
└── voice/
```

## Naming convention

```
{category}_{system}_{action}_{variant}.{ext}
```

| Pattern | Example |
|---------|---------|
| `sfx_player_jump_01.wav` | Player jump variant 1 |
| `sfx_player_jump_02.wav` | Variant 2 (random pitch via AudioManager) |
| `sfx_player_land.wav` | Single-take SFX |
| `sfx_enemy_hit.wav` | Generic enemy hit |
| `sfx_ui_button_hover.wav` | Button hover |
| `sfx_ui_button_click.wav` | Button click |
| `sfx_ui_menu_open.wav` | Menu transition |
| `sfx_combat_attack_melee_01.wav` | Melee variant |
| `sfx_world_door_open.wav` | World object |
| `sfx_pickup_coin.wav` | Pickup |
| `music_menu_theme.ogg` | Menu music |
| `music_level_01.ogg` | Level music |
| `music_boss.ogg` | Boss music |
| `ambience_forest_day.ogg` | Loop |

Numbered variants (`_01`, `_02`, `_03`) for any sound that plays often — pick at random + slight pitch variation to avoid ear fatigue.

## Generation workflow

### Step 1: identify what you need

| Need | Format | Length |
|------|--------|--------|
| Footstep, click, ping | `.wav` | < 0.5s |
| Attack, jump, pickup | `.wav` | 0.3 – 1s |
| Big hit, explosion | `.wav` | 1 – 3s |
| Music loop | `.ogg` | 30s – 3min |
| Ambience loop | `.ogg` | 1 – 3min |

### Step 2: generate

**ElevenLabs MCP (`text_to_sound_effects`):**

Good prompts are **specific**: material, intensity, distance, mood.

| Bad | Good |
|-----|------|
| "Sword sound" | "Steel sword unsheathed from leather scabbard, metallic ring, close mic" |
| "Magic" | "Frost magic spell cast, crystalline shimmer rising in pitch over 1 second" |
| "Jump" | "Cartoon character jump squeak, light woof, bouncy" |
| "Hit" | "Punchy fist hit on flesh, deep impact thud with subtle crunch" |

**MusicGPT MCP** for music tracks: specify mood, tempo (BPM), instruments, genre, target length.

### Step 3: free fallback sources

| Site | License | Best for |
|------|---------|----------|
| [freesound.org](https://freesound.org) | CC0 / CC-BY | SFX search |
| [opengameart.org](https://opengameart.org) | mixed (filter) | SFX + music |
| [kenney.nl/assets](https://kenney.nl/assets) | CC0 | UI / game sound packs |
| [incompetech.com](https://incompetech.com) | CC-BY (Kevin MacLeod) | Royalty-free music |
| [bbc.co.uk/sounds/effects](https://sound-effects.bbcrewind.co.uk/) | various | Recorded foley |

## Audio bus layout

Set up in **Audio → Audio Bus** panel. Save the layout as `default_bus_layout.tres`.

```
Master
├── Music
├── SFX
│   ├── Player
│   ├── Enemy
│   ├── UI
│   └── World
├── Voice
└── Ambience
```

Effects per bus:

- `Music`: Compressor (gentle), Limiter
- `SFX`: Limiter
- `Voice`: Compressor (heavier), HighPassFilter
- `Ambience`: LowPassFilter (subtle)
- `Master`: Limiter at -1 dB ceiling

Volume reference (set in code via `AudioServer.set_bus_volume_db(bus_idx, db)`):

| Bus | Default dB |
|-----|-----------|
| Master | 0 |
| Music | -8 |
| SFX | -3 |
| Voice | -3 |
| Ambience | -10 |

## AudioManager pattern

```gdscript
# autoload/audio_manager.gd
extends Node

const SFX_POOL_SIZE := 16

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary[StringName, Array] = {}  # name -> Array[AudioStream] variants


func _ready() -> void:
    for i in SFX_POOL_SIZE:
        var p := AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        _sfx_players.append(p)
    _load_sfx_variants()


func play_sfx(name: StringName, pitch_variation: float = 0.1) -> void:
    var variants: Array = _sfx_cache.get(name, [])
    if variants.is_empty():
        push_warning("SFX not found: %s" % name)
        return
    var p := _get_free_player()
    if p == null:
        return
    p.stream = variants.pick_random()
    p.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
    p.play()


func _get_free_player() -> AudioStreamPlayer:
    for p in _sfx_players:
        if not p.playing:
            return p
    return null


func _load_sfx_variants() -> void:
    # Group _01, _02, ... as variants of same name
    var dir := DirAccess.open("res://assets/audio/sfx")
    # Walk dir, group by base name without _NN suffix, populate _sfx_cache.
    pass
```

For positional 2D/3D sounds use `AudioStreamPlayer2D` / `AudioStreamPlayer3D` instead — pool the same way.

## Music crossfade

```gdscript
func crossfade_music(new_stream: AudioStream, duration: float = 1.5) -> void:
    var fading := _music_player_a if _active_music == _music_player_b else _music_player_b
    var rising := _music_player_b if fading == _music_player_a else _music_player_a
    rising.stream = new_stream
    rising.volume_db = -80.0
    rising.play()
    var tw := create_tween().set_parallel()
    tw.tween_property(fading, "volume_db", -80.0, duration)
    tw.tween_property(rising, "volume_db", _music_target_db, duration)
    tw.chain().tween_callback(fading.stop)
    _active_music = rising
```

For stinger-driven transitions consider `AudioStreamInteractive` (Godot 4.3+).

## Import settings (Godot)

| File type | Loop | Compress |
|-----------|------|----------|
| Music `.ogg` | yes | yes (default) |
| Ambience `.ogg` | yes | yes |
| SFX `.wav` | no | no |

Set in the **Import** dock. Save defaults via "Set as Default for ..." so future imports inherit.
