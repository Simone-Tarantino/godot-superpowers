---
name: create-scene
description: Scaffold a new Godot 4.x scene from genre-agnostic templates — 2D/3D player, enemy, level, main menu, pause menu, HUD, inventory UI, dialogue UI. Picks the right root node, wires signals in code, follows composition pattern.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: <template> <name>
---

# Create a Scene

Templates available. Pass `<template> <name>` (e.g. `2d-player Player`, `3d-character Hero`, `main-menu MainMenu`).

If no template matches, fall back to manual scaffolding using the principles in [`godot-patterns`](../godot-patterns/SKILL.md).

## Templates

### `2d-player` — CharacterBody2D player

```
{Name} (CharacterBody2D)
├── Sprite2D (or AnimatedSprite2D)
├── CollisionShape2D
├── Hurtbox (Area2D)            -> takes damage; layer: PlayerHurtbox
│   └── CollisionShape2D
├── Hitbox (Area2D)             -> deals damage; layer: PlayerHitbox
│   └── CollisionShape2D
├── HealthComponent (Node)
├── StateMachine (Node)
│   ├── Idle (Node)
│   ├── Run (Node)
│   ├── Jump (Node)
│   └── Fall (Node)
├── Camera2D (optional, for player-following)
└── AnimationPlayer
```

Script: `extends CharacterBody2D`, `class_name Player`. Connect `Hurtbox.area_entered` and forward to `HealthComponent.take_damage`. Use `setup-collision-layers` skill for the layer config.

The Player scene **re-emits HealthComponent's signals** so coordinators can connect on the root node instead of digging into children:

```gdscript
class_name Player
extends CharacterBody2D

signal health_changed(old: float, new: float)
signal died

@onready var _health: HealthComponent = $HealthComponent


func _ready() -> void:
    _health.health_changed.connect(func(old, new): health_changed.emit(old, new))
    _health.died.connect(func(): died.emit())
```

### `3d-character` — CharacterBody3D player or NPC

```
{Name} (CharacterBody3D)
├── MeshInstance3D (or Skeleton3D for rigged)
├── CollisionShape3D
├── Hurtbox (Area3D)
│   └── CollisionShape3D
├── HealthComponent (Node)
├── StateMachine (Node)
├── CameraPivot (Node3D)         -> rotated by input
│   └── SpringArm3D              -> collision-aware camera arm
│       └── Camera3D
├── AnimationPlayer / AnimationTree
└── NavigationAgent3D (NPCs only)
```

Script: set `velocity`, call `move_and_slide()`. Camera: rotate `CameraPivot` from mouse/stick.

### `2d-enemy` / `3d-enemy`

```
{Name} (CharacterBody2D | CharacterBody3D)
├── Sprite2D | MeshInstance3D
├── CollisionShape2D | CollisionShape3D
├── Hurtbox (Area)               -> EnemyHurtbox layer
├── Hitbox (Area)                -> EnemyHitbox layer
├── HealthComponent
├── StateMachine                 -> Patrol, Chase, Attack, Stunned
├── DetectionArea (Area)         -> sees player
├── NavigationAgent (2D or 3D)
└── AnimationPlayer
```

### `level` — generic level/world container

```
{Name}Level (Node2D | Node3D)
├── World
│   ├── TileMapLayer (2D) | GridMap (3D)
│   ├── StaticBody / collision
│   └── NavigationRegion (2D or 3D)
├── Entities (Node)
│   ├── PlayerSpawn (Marker2D | Marker3D)
│   ├── EnemySpawns (Node)
│   └── Pickups (Node)
├── Triggers (Node)              -> Area-based events
├── HUD (CanvasLayer)
│   └── ...
├── DirectionalLight3D / WorldEnvironment (3D only)
└── Music (AudioStreamPlayer)
```

### `main-menu`

```
{Name}MainMenu (Control)
├── Background (TextureRect | ColorRect | Node3D viewport)
├── MarginContainer
│   └── VBoxContainer
│       ├── TitleLabel
│       └── ButtonContainer (VBoxContainer)
│           ├── PlayButton
│           ├── ContinueButton
│           ├── OptionsButton
│           ├── CreditsButton
│           └── QuitButton
├── VersionLabel (Label, anchored bottom-right)
└── Music (AudioStreamPlayer)
```

Set `anchors_preset = PRESET_FULL_RECT`. Use focus_neighbor_* for gamepad nav. Connect `pressed` signals in `_ready`.

### `pause-menu`

```
{Name}PauseMenu (CanvasLayer)
├── DimBackground (ColorRect, anchored full)
├── Panel
│   └── VBoxContainer
│       ├── ResumeButton
│       ├── OptionsButton
│       └── QuitButton
```

Set `process_mode = PROCESS_MODE_WHEN_PAUSED` on the root. Toggle `get_tree().paused` from a controller node.

### `hud` — gameplay HUD overlay

```
{Name}HUD (CanvasLayer)
├── TopBar (HBoxContainer, anchored top)
│   ├── HealthBar (TextureProgressBar)
│   ├── ScoreLabel
│   └── PauseIcon
├── BottomBar (HBoxContainer, anchored bottom)
│   ├── InventoryBar
│   └── AbilityBar
└── CenterPopup (Control)        -> "Level Up!", "Wave 1", etc.
```

Subscribe to `EventBus` signals in `_ready` (e.g. `EventBus.health_changed.connect(_on_health)`).

### `inventory-ui`

```
{Name}InventoryUI (Control)
├── Background (Panel)
├── HSplitContainer
│   ├── ItemGrid (GridContainer, scrollable)
│   └── DetailPanel (VBoxContainer)
│       ├── ItemIcon (TextureRect)
│       ├── ItemName (Label)
│       ├── ItemDescription (RichTextLabel)
│       └── UseButton
└── CloseButton
```

Each `ItemGrid` slot = scene with `Item` resource binding. Emit `item_selected(item)` to update `DetailPanel`.

### `dialogue-ui`

```
{Name}DialogueUI (CanvasLayer)
├── DialogueBox (PanelContainer, anchored bottom)
│   ├── PortraitTexture
│   ├── VBoxContainer
│   │   ├── SpeakerLabel
│   │   └── DialogueLabel (RichTextLabel, BBCode enabled)
│   └── ContinueIndicator
└── ChoicesContainer (VBoxContainer)   -> dynamic Button children
```

Use `RichTextLabel.visible_ratio` tween for typewriter effect.

## Mandatory checklist for any scene

1. Root node = the most specific class needed (`CharacterBody2D`, `Control`, `Node3D`, etc.)
2. `class_name` set if scene is reusable from code
3. Script with file-top docstring (one-line purpose)
4. Signals connected in code in `_ready()`, not via editor
5. Components as child nodes (composition, not deep `extends`)
6. Materials/Themes set in code only when dynamic; otherwise drag a `.tres`
7. `@onready` for any node accessed more than once
8. Unique names (`%`) for important child nodes accessed from script
9. Add to relevant groups: `add_to_group("enemies")`, `add_to_group("persist")`, etc.
10. Set `process_mode` correctly if the scene must behave differently when paused
11. Collision layers set per the convention from `setup-collision-layers`

## Coordinator pattern (for orchestrating scenes)

A scene root can act as a coordinator: it wires signals between subsystems in `_ready()` but holds no internal logic itself. Each child subsystem is self-contained and testable in isolation.

```gdscript
extends Node2D
class_name BattleScene

@onready var grid_manager: GridManager = $GridManager
@onready var player: Player = $Player
@onready var hud: HUD = $HUD


func _ready() -> void:
    player.health_changed.connect(hud.update_health)
    player.died.connect(_on_player_died)
    grid_manager.cell_clicked.connect(_on_cell_clicked)


func _on_player_died() -> void:
    SceneManager.change_to("res://scenes/ui/game_over.tscn")
```
