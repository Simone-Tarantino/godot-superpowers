---
name: gut-test-writer
description: Write GUT (Godot Unit Test) tests for components, scenes, autoloads. Generates test structure, before_each/after_each setup, signal watching, parameterized tests, headless run config, and CI integration. Use after implementing a feature or fixing a bug.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: <target-script-or-scene>
---

# GUT Test Writer

Generate [GUT](https://github.com/bitwes/Gut) tests. For GdUnit4, see the `qa-tester` agent — same patterns, different API.

## Setup (once per project)

1. Install GUT via Asset Library or git submodule into `addons/gut/`
2. Enable in **Project Settings → Plugins**
3. Create `test/.gutconfig.json`:

```json
{
  "dirs": ["res://test/unit", "res://test/integration"],
  "include_subdirs": true,
  "log_level": 1,
  "should_exit": true,
  "should_exit_on_success": true,
  "junit_xml_file": "res://test/reports/results.xml",
  "junit_xml_timestamp": false
}
```

4. Add to `.gitignore`: `test/reports/`

## Directory structure

```
test/
├── unit/
│   ├── test_health_component.gd
│   ├── test_inventory.gd
│   └── test_state_machine.gd
├── integration/
│   ├── test_player_takes_damage.gd
│   └── test_save_load_roundtrip.gd
├── helpers/
│   ├── test_helpers.gd       # shared fixtures
│   └── mock_player.gd
├── fixtures/
│   └── test_save_data.tres
├── reports/                  # gitignored
└── .gutconfig.json
```

Filename convention: `test_{thing_under_test}.gd`. Class: `extends GutTest`.

## Test template

```gdscript
extends GutTest
## Tests for HealthComponent.

const HealthComponent := preload("res://scripts/components/health_component.gd")

var _hp: HealthComponent


func before_each() -> void:
    _hp = HealthComponent.new()
    _hp.max_health = 100
    add_child_autofree(_hp)
    _hp._ready()  # _ready is called when added; explicit here for clarity


func test_starts_at_full_health() -> void:
    assert_eq(_hp.current_health, 100)


func test_take_damage_reduces_health() -> void:
    _hp.take_damage(30)
    assert_eq(_hp.current_health, 70)


func test_take_damage_clamps_at_zero() -> void:
    _hp.take_damage(9999)
    assert_eq(_hp.current_health, 0)


func test_die_signal_emitted_at_zero() -> void:
    watch_signals(_hp)
    _hp.take_damage(100)
    assert_signal_emitted(_hp, "died")


func test_health_changed_payload() -> void:
    watch_signals(_hp)
    _hp.take_damage(25)
    assert_signal_emitted_with_parameters(_hp, "health_changed", [100, 75])


func test_invulnerable_blocks_damage() -> void:
    _hp.invulnerable = true
    _hp.take_damage(50)
    assert_eq(_hp.current_health, 100)


func test_heal_does_not_overshoot_max() -> void:
    _hp.take_damage(20)
    _hp.heal(50)
    assert_eq(_hp.current_health, 100)


func test_revive_after_death() -> void:
    _hp.take_damage(100)
    watch_signals(_hp)
    _hp.revive()
    assert_signal_emitted(_hp, "revived")
    assert_eq(_hp.current_health, 100)
```

## Scene-based tests

```gdscript
extends GutTest
## Player integration test — instantiates the full scene.

const PlayerScene := preload("res://scenes/player/player.tscn")

var _player: Player


func before_each() -> void:
    _player = PlayerScene.instantiate()
    add_child_autofree(_player)
    await get_tree().process_frame   # let _ready propagate to children


func test_player_dies_when_hp_zero() -> void:
    watch_signals(_player)
    _player.get_node("HealthComponent").take_damage(_player.get_node("HealthComponent").max_health)
    assert_signal_emitted(_player, "died")
```

## Parameterized tests

```gdscript
func test_damage_modifier(params = use_parameters([
    [1.0, 100, 10],   # full damage
    [0.5, 100, 5],    # half damage
    [2.0, 100, 20],   # double damage
    [0.0, 100, 0],    # immune
])) -> void:
    var modifier: float = params[0]
    var input_dmg: int = params[1]
    var expected: int = params[2]
    _hp.damage_modifier = modifier
    var before := _hp.current_health
    _hp.take_damage(input_dmg)
    assert_eq(before - _hp.current_health, expected)
```

## Mock / spy patterns

```gdscript
# Spy on a method by replacing the implementation
class MockAudioManager extends Node:
    var played: Array[StringName] = []

    func play_sfx(name: StringName, _pitch_variation: float = 0.1) -> void:
        played.append(name)


func test_player_plays_jump_sfx() -> void:
    var mock := MockAudioManager.new()
    add_child_autofree(mock)
    # inject mock into player (via @export or setter)
    _player.audio_manager = mock
    _player.jump()
    assert_has(mock.played, &"sfx_player_jump_01")
```

For deeper mocking, GUT provides `partial_double()` and `double()` — see GUT docs.

## Asserting timing / async

```gdscript
func test_dash_cooldown() -> void:
    _player.dash()
    assert_true(_player.is_dashing())
    await get_tree().create_timer(_player.dash_duration + 0.1).timeout
    assert_false(_player.is_dashing())
```

For shorter waits use `await get_tree().process_frame` (one frame) or `await get_tree().physics_frame` (one physics tick).

## Headless run

```bash
# all tests, exit on completion
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit

# specific directory
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit

# specific file
godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_health_component.gd -gexit

# with JUnit XML output
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -gjunit_xml_file=res://test/reports/results.xml -gexit
```

Exit code: 0 on success, non-zero on test failure.

## CI integration (GitHub Actions)

`.github/workflows/test.yml`:

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: chickensoft-games/setup-godot@v2
        with:
          version: 4.4.1
          use-dotnet: false
      - name: Import project
        run: godot --headless --import || true
      - name: Run GUT tests
        run: |
          godot --headless --path . \
            -s addons/gut/gut_cmdln.gd \
            -gdir=res://test \
            -gjunit_xml_file=res://test/reports/results.xml \
            -gexit
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-reports
          path: test/reports/
```

## Test design rules

- **One assertion per test**, ideally. Tests with many asserts hide which one failed.
- **`before_each`** sets up; **`after_each`** is rarely needed if you use `add_child_autofree`.
- **No file I/O** in unit tests — mock `FileAccess` or test against fixtures in `test/fixtures/`.
- **No autoloads** in unit tests — test the component in isolation. Integration tests can use the real autoload.
- **Test edge cases first**: zero, negative, max, empty array, missing dependency.
- **Test signal payloads**, not just emission count — payload bugs are common.
- **Don't test private methods directly**. Test the observable behavior.
