---
name: ui-patterns-godot
description: Build correct UI in Godot 4.x — Theme + StyleBox setup, Control focus management, `_unhandled_input` vs `_gui_input`, anchors and containers, stretch_mode + content_scale_size for responsive UI, CanvasLayer for HUD, accessibility basics (focus indicators, font scaling, contrast). Use whenever scaffolding menus, HUDs, settings screens, or any `Control`-tree work.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# UI patterns (Godot 4.x)

Godot's UI system is powerful and *very* easy to misuse. Three failure modes drive 80% of UI bugs in indie projects:

1. Input "passes through" the UI to gameplay (because of `_input` vs `_unhandled_input` mix-up or missing `accept_event()`).
2. UI scales wrong on different resolutions (because `content_scale_size` was never set).
3. Theming is ad-hoc per scene (because no `Theme.tres` was authored — every menu carries inline overrides).

This skill is the canonical fix for all three. It is generic, not genre-specific. For game-specific HUD shapes (health bar, ammo counter, dialogue box) see [`create-scene`](../create-scene/SKILL.md).

## 1. Project-level UI settings

Set these in `project.godot` once, then forget. Reference: [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"      # 2D pixel-perfect; use "viewport" for low-res pixel art
window/stretch/aspect="expand"           # adds black bars only when extreme
window/stretch/scale_mode="fractional"

[gui]

theme/custom="res://ui/theme.tres"        # project-wide Theme
theme/default_font_size=18
common/snap_controls_to_pixels=true
```

| Stretch mode | Use for |
|--------------|---------|
| `disabled` | UI scales 1:1 with the window — only correct for tools / desktop apps |
| `canvas_items` | Vector-style UI; sharp at any resolution; **default for most modern games** |
| `viewport` | Low-res pixel-art games — renders to a fixed-size viewport, then scales the whole framebuffer |

## 2. Theme — single source of truth

A `Theme.tres` resource maps node-class + state → `StyleBox`, font, color, icon. Author it **once** in `res://ui/theme.tres` and reference it from `project.godot` (`gui/theme/custom`). Every `Control` inherits it unless explicitly overridden.

Build a Theme via the editor (Inspector → New Theme on any Control), or programmatically:

```gdscript
@tool
extends EditorScript
## One-shot Theme builder. Run from Editor → File → Run.
## Produces res://ui/theme.tres with consistent styling.

const THEME_PATH := "res://ui/theme.tres"

func _run() -> void:
    var theme := Theme.new()
    var font := load("res://ui/fonts/Inter-Regular.ttf") as FontFile
    theme.default_font = font
    theme.default_font_size = 18

    # Button — normal / hover / pressed / focus / disabled
    theme.set_stylebox("normal",   "Button", _box(Color("1f1f24"), Color("3a3a44")))
    theme.set_stylebox("hover",    "Button", _box(Color("2a2a30"), Color("5a5a66")))
    theme.set_stylebox("pressed",  "Button", _box(Color("141418"), Color("8a8a99")))
    theme.set_stylebox("focus",    "Button", _focus_ring())
    theme.set_stylebox("disabled", "Button", _box(Color("18181c"), Color("2a2a30")))
    theme.set_color("font_color",          "Button", Color("e8e8ec"))
    theme.set_color("font_disabled_color", "Button", Color("6a6a72"))

    ResourceSaver.save(theme, THEME_PATH)
    print("Theme saved to ", THEME_PATH)

func _box(bg: Color, border: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    sb.content_margin_left = 12
    sb.content_margin_right = 12
    sb.content_margin_top = 6
    sb.content_margin_bottom = 6
    return sb

func _focus_ring() -> StyleBoxFlat:
    var sb := _box(Color(0, 0, 0, 0), Color("4a9eff"))
    sb.set_border_width_all(2)
    return sb
```

Authoring rule: **if a Control needs a unique look, add a Theme variation** (`theme_type_variation = "PrimaryButton"`) and define `PrimaryButton` styles in the Theme. Do not pile inline `add_theme_*_override` calls in scenes.

## 3. Containers — pick the right one

Containers position children automatically. Setting size/position manually inside a Container is fighting the engine.

| Container | When | Notes |
|-----------|------|-------|
| `VBoxContainer` / `HBoxContainer` | Stack of items along one axis | Use `add_theme_constant_override("separation", N)` for spacing |
| `MarginContainer` | Add inner padding around a child | One child only |
| `CenterContainer` | Center child(ren) within available space | Children keep their min size |
| `GridContainer` | Fixed-column grid (e.g. inventory) | Set `columns` |
| `ScrollContainer` | Scroll a child larger than the viewport | Child must declare a min size or it collapses |
| `TabContainer` | Tabbed panels | Each child node becomes a tab |
| `AspectRatioContainer` | Letterbox a child to a fixed aspect | Useful for 16:9 game viewports inside a Control UI |

Anchors apply to `Control` children of *non-container* parents. Inside a Container, anchors are ignored — the Container drives layout.

## 4. Input layering — UI vs gameplay

**The rule**: gameplay listens on `_unhandled_input(event)`. UI listens on `_gui_input(event)` (per-Control) or `_input(event)` for global shortcuts. The engine guarantees `_unhandled_input` only fires after `_gui_input` had its chance. Reference: [InputEvent flow](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html#how-does-it-work).

```
Engine input pipeline:
  Window event
    → Node._input()
        → Control._gui_input()  (only on Controls under the mouse / focused)
            → if accept_event() called  → STOP
            → else propagate up the Control tree
        → Node._unhandled_input()       (gameplay handlers live HERE)
        → Node._unhandled_key_input()
```

Practical pattern:

```gdscript
# scripts/player.gd  — gameplay, must NOT fire while a menu is open.
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("jump"):
        velocity.y = JUMP_VELOCITY
```

```gdscript
# ui/pause_menu.gd  — UI button consumes its own clicks.
func _ready() -> void:
    %ResumeButton.pressed.connect(_on_resume)

func _gui_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _on_resume()
        accept_event()    # <-- prevents propagation; gameplay never sees ui_cancel here
```

**Common bug**: you used `_input(event)` in the player script. Now opening a menu does not stop the player from acting on the same key, because `_input` runs *before* the GUI gets a chance. Move the handler to `_unhandled_input`.

## 5. Focus management (gamepad + keyboard)

Players using gamepad or keyboard navigate by focus, not mouse. A menu without a configured focus chain is broken on those inputs.

```gdscript
extends Control
## Wires up a focus chain on _ready so D-pad / arrow keys cycle correctly.

@onready var resume: Button   = %ResumeButton
@onready var settings: Button = %SettingsButton
@onready var quit: Button     = %QuitButton

func _ready() -> void:
    resume.focus_neighbor_bottom   = settings.get_path()
    settings.focus_neighbor_top    = resume.get_path()
    settings.focus_neighbor_bottom = quit.get_path()
    quit.focus_neighbor_top        = settings.get_path()
    resume.grab_focus()    # entry point
```

Default rules:

- Every interactive Control has `focus_mode = FOCUS_ALL` (or `FOCUS_CLICK` for mouse-only — rare; usually wrong).
- The first focusable Control should call `grab_focus()` in `_ready()` (or `await get_tree().process_frame; grab_focus()` if it's added late).
- The Theme **must** define the `focus` StyleBox for each interactive class — without it, the focused Control is invisible to keyboard users.
- For dynamically-built menus (e.g. inventory grid), wire neighbors after spawning the items, not in the editor.

## 6. CanvasLayer — separate UI from world

A HUD that lives in the same scene as the world is a HUD that scrolls with the camera. Wrap UI in a `CanvasLayer`:

```
Game (Node2D)
├── World (Node2D)
│   ├── Player
│   └── Level
└── HUD (CanvasLayer)
    └── HUDRoot (Control)
        ├── HealthBar
        └── AmmoCounter
```

`CanvasLayer.layer` = `0` is default; `1+` renders on top of world. Use `100` for transient overlays (loading screen, fade) so they always win.

## 7. SubViewport — UI that needs its own render

Use a `SubViewport` only when you need a 3D model preview inside a UI panel, an in-world screen showing a mini-map, or a render-to-texture effect. Do NOT use it for normal UI — it adds a render pass for nothing. Reference: [Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html).

```
PortraitPanel (Panel)
└── SubViewportContainer
    └── SubViewport
        ├── Camera3D
        └── PlayerModel (Node3D)
```

`SubViewportContainer.stretch = true` to size the viewport to the container.

## 8. Accessibility floor

Bare-minimum accessibility is mostly free if you do these once:

- **Contrast**: text foreground vs background ≥ 4.5:1 (use a contrast checker — most "dark cool grey on slightly less dark grey" themes fail this).
- **Focus indicator**: the `focus` StyleBox in the Theme must be visibly different — a 2px ring in a high-contrast color is enough.
- **Font scaling**: expose a UI-scale slider in settings that calls `get_tree().root.content_scale_factor = scale` (Godot 4.x). Do NOT just bump font sizes on Controls — that breaks layout. Content scale factor scales the whole UI consistently.
- **No reliance on color alone**: red vs green status icons fail for the ~5% of players with red-green color blindness; pair with a shape/icon difference.
- **Caption / subtitle layer** for any spoken dialogue, even early in development — retrofitting later is much harder than scaffolding the layer up front.
- **Input remapping**: ship a remap UI ([`setup-input-map`](../setup-input-map/SKILL.md) covers this).

## 9. Common bugs (and the fix)

| Bug | Cause | Fix |
|-----|-------|-----|
| Clicking a button also moves the player | Gameplay handler in `_input`, not `_unhandled_input` | Move handler to `_unhandled_input` |
| Tab / arrow keys don't navigate menus | `focus_mode` not set or no focus chain | Set `focus_mode = FOCUS_ALL` and wire `focus_neighbor_*` |
| Pressed key fires twice (UI + gameplay) | Missing `accept_event()` after handling | Call `accept_event()` in `_gui_input` after consuming |
| Settings menu looks different from main menu | Inline overrides instead of Theme | Author `Theme.tres`, reference from `project.godot` |
| HUD scrolls with camera | HUD parented to world | Wrap in `CanvasLayer` |
| UI elements overlap on widescreen | Anchors set to corner instead of stretching | Use a Container; anchors inside Containers are ignored anyway |
| Tooltip clips at screen edge | Default tooltip behavior | Use a custom Control as `tooltip_text` source via `_make_custom_tooltip` |
| `ScrollContainer` child collapses to nothing | Child has no min size | Set `custom_minimum_size` on the child |

## 10. When to call out for help

- Designing a full menu flow with branching screens → pair with `game-designer` for screen-state machine design, then implement here.
- Building a layout that depends on dynamic data (inventory grid sized to item count) → use `GridContainer.columns` + child instantiation; do NOT compute positions manually.
- Need pixel-perfect retro UI with custom shaders → use `viewport` stretch mode plus a dedicated `SubViewport` render layer; consult the shader-writer skill.

## See also

- [Custom GUI controls](https://docs.godotengine.org/en/stable/tutorials/ui/custom_gui_controls.html)
- [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- [InputEvent flow](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html#how-does-it-work)
- [`setup-input-map`](../setup-input-map/SKILL.md) — pair this skill with input remapping for accessible controls
- [`create-scene`](../create-scene/SKILL.md) — game-specific HUD / menu templates use the patterns documented here
