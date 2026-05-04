---
name: setup-input-map
description: Configure Godot 4.x InputMap with standard actions (move, jump, attack, interact, pause, UI nav) for keyboard, mouse, and gamepad. Generate a runtime remap UI as a bonus. Edits project.godot.
allowed-tools: Read, Write, Edit
argument-hint: [genre: platformer | topdown | 3d-action | fps | turnbased]
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Setup Input Map

Configures Godot 4.x [InputMap](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) actions and provides a remap UI scaffold.

## Default actions (genre-agnostic)

| Action | Keyboard | Gamepad | Notes |
|--------|----------|---------|-------|
| `move_left` | A, Left | LStick left, DPad left | |
| `move_right` | D, Right | LStick right, DPad right | |
| `move_up` | W, Up | LStick up, DPad up | |
| `move_down` | S, Down | LStick down, DPad down | |
| `jump` | Space | A (Xbox) / X (PS) | platformer / 3d |
| `attack` | LMB, J | RT / R2 | |
| `attack_secondary` | RMB, K | LT / L2 | block / heavy |
| `interact` | E | Y / Triangle | |
| `dash` | Shift | B / Circle | |
| `inventory` | I | Select / Share | |
| `pause` | Esc | Start / Options | |
| `ui_accept` | Enter, Space | A | also auto-mapped by engine |
| `ui_cancel` | Esc | B | engine default |
| `ui_left/right/up/down` | arrows | DPad | engine default |

`ui_*` actions exist by default — adjust as needed but don't remove (Control nodes rely on them).

## `project.godot` — `[input]` section

```ini
[input]

move_left={
"deadzone": 0.5,
"events": [
  Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null),
  Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null),
  Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":0,"axis_value":-1.0,"script":null),
  Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":13,"pressure":0.0,"pressed":false,"script":null)
]
}
```

(That's just `move_left`. The full block is verbose — easier to add actions through the editor's Input Map panel and let Godot serialize. **Recommended**: open Project Settings → Input Map, click "Add" for each action listed above, bind keys/buttons, then save.)

Physical keycode reference (`physical_keycode`):
- A=65, S=83, D=68, W=87
- Space=32
- Left=4194319, Right=4194321, Up=4194320, Down=4194322
- Esc=4194305, Enter=4194309
- Shift=4194325

Gamepad button indices (Xbox layout):
- 0=A, 1=B, 2=X, 3=Y
- 4=LB, 5=RB
- 6=Select, 7=Start
- 11=DPad up, 12=DPad down, 13=DPad left, 14=DPad right

Joypad axes:
- 0=LStick X, 1=LStick Y, 2=RStick X, 3=RStick Y
- 4=LT, 5=RT

## Reading input in code

```gdscript
# Movement vector (handles 8-direction + analog stick)
var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
velocity.x = input_dir.x * MAX_SPEED

# One-shot in _unhandled_input (preferred for actions)
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("jump"):
        _try_jump()
    elif event.is_action_pressed("pause"):
        _toggle_pause()

# Held check in _physics_process
if Input.is_action_pressed("attack"):
    _charge_attack(delta)

# Just-pressed in _physics_process (alternative to _unhandled_input)
if Input.is_action_just_pressed("dash"):
    _dash()
```

## Genre-specific additions

### Platformer
- `jump` (already in defaults)
- `crouch` — Ctrl, Down (modifier)
- `wall_grab` — Shift held

### 3D action / FPS
- `look_left/right/up/down` (mouse fallback for keyboard-only)
- `aim` — RMB / L2
- `fire` — LMB / R2
- `reload` — R / X(Square)
- `zoom_in/out` — scroll wheel

### Top-down shooter
- Same as 3D action, omit jump

### Turn-based
- `confirm` — Space, Enter, A
- `cancel` — Esc, B
- `next_unit` — Tab, RB
- `end_turn` — F, Start

## Runtime remap UI

`scenes/ui/input_remap_menu.tscn` skeleton. **Mark `ActionList` and `ResetButton` as unique names** (`%ActionList`, `%ResetButton`) in the editor so the controller can grab them:

```
InputRemapMenu (Control)
├── VBoxContainer
│   ├── ScrollContainer
│   │   └── ActionList (VBoxContainer, unique name %ActionList — action rows generated at runtime)
│   └── HBoxContainer
│       ├── ResetButton (Button, unique name %ResetButton, text "Reset to defaults")
│       └── BackButton (Button, optional)
```

Controller `scripts/ui/input_remap_menu.gd`:

```gdscript
extends Control

const REMAPPABLE := [
    "move_left", "move_right", "move_up", "move_down",
    "jump", "attack", "interact", "dash", "pause",
]
const SAVE_PATH := "user://input_map.cfg"

@onready var _list: VBoxContainer = %ActionList
@onready var _reset_button: Button = %ResetButton
var _capturing_action: StringName = &""
var _row_for_action: Dictionary[StringName, HBoxContainer] = {}


func _ready() -> void:
    _reset_button.pressed.connect(_on_reset_pressed)
    _load_overrides()
    _build_rows()


func _on_reset_pressed() -> void:
    InputMap.load_from_project_settings()
    DirAccess.remove_absolute(SAVE_PATH)
    _build_rows()


func _build_rows() -> void:
    for child in _list.get_children():
        child.queue_free()
    for action in REMAPPABLE:
        var row := HBoxContainer.new()
        var label := Label.new()
        label.text = action
        label.custom_minimum_size.x = 200
        var btn := Button.new()
        btn.text = _format_event(InputMap.action_get_events(action))
        btn.pressed.connect(_capture.bind(action, btn))
        row.add_child(label)
        row.add_child(btn)
        _list.add_child(row)
        _row_for_action[action] = row


func _capture(action: StringName, btn: Button) -> void:
    _capturing_action = action
    btn.text = "press a key..."


func _input(event: InputEvent) -> void:
    if _capturing_action == &"":
        return
    if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
        if event.pressed:
            InputMap.action_erase_events(_capturing_action)
            InputMap.action_add_event(_capturing_action, event)
            _save_overrides()
            _build_rows()
            _capturing_action = &""
            get_viewport().set_input_as_handled()


func _format_event(events: Array[InputEvent]) -> String:
    if events.is_empty():
        return "(unbound)"
    return events[0].as_text()


func _save_overrides() -> void:
    var cfg := ConfigFile.new()
    for action in REMAPPABLE:
        var events := InputMap.action_get_events(action)
        cfg.set_value("input", action, events)
    cfg.save(SAVE_PATH)


func _load_overrides() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    for action in REMAPPABLE:
        var events: Array = cfg.get_value("input", action, [])
        if events.is_empty():
            continue
        InputMap.action_erase_events(action)
        for ev in events:
            InputMap.action_add_event(action, ev)
```

Persists to `user://input_map.cfg` and restores at startup.

## Notes

- Use `physical_keycode` (positional) not `keycode` (layout-dependent) for movement keys — works across QWERTY / AZERTY / Dvorak.
- `Input.is_action_pressed()` is fine in `_physics_process`; for one-shots prefer `_unhandled_input` so UI captures take precedence.
- For couch co-op, set `device` on each `InputEvent` and read with `Input.is_joy_known(device)`.
