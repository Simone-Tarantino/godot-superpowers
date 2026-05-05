---
name: save-schema-migration
description: Version save data and migrate old saves forward when the schema changes — `schema_version` on every save Resource, sequential migration registry (v1→v2→v3, never skip), fallback for unknown versions, regression tests that load fixture saves from each released version. Use when a save format change is about to ship, or when adding versioning to a project that does not yet have it.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Save schema migration

A shipped game inherits every save format it ever published. The first time you add a field to `SaveData` and re-export, every existing player loads a save with the *old* shape and gets either: silent data loss (missing field defaults to zero), a hard crash (`null.method()` on a missing sub-Resource), or a corrupt run.

This skill is the contract for evolving save data without breaking existing players. Pair it with [`setup-save-system`](../setup-save-system/SKILL.md), which already includes a `version` field and a `_migrate()` stub — this skill fills in the migration registry and the test that proves it works.

## Rules

1. **Every save Resource has a `schema_version: int`** at the top level. Bump it whenever you add, remove, rename, or change the meaning of a field.
2. **Migrations are sequential.** A v1 save migrates to v2, then v2 to v3 — never v1 → v3 directly. This keeps each migration small and independently testable.
3. **Migrations are pure functions** of the loaded payload. They do not read the current scene, the autoloads, or anything else — same input → same output.
4. **Migrations never delete data without an explicit decision.** Renaming a field? Move the value. Removing? Either drop silently with a comment or stash under `_legacy.<field_name>` if there is any chance you'll want it back.
5. **Every released version has a fixture save** in `test/fixtures/save/v<N>.tres`. CI loads each fixture and asserts the migrated result matches the current schema's `assert_valid()` invariants.
6. **Unknown future version = refuse to load.** A v5 save loaded by a v3 build means the player rolled back. Do not guess — show "save from a newer version, please update".

## File shape

### `resources/save_data.gd` (extended from `setup-save-system`)

```gdscript
class_name SaveData
extends Resource
## Top-level save container. One file per slot.
##
## When `SCHEMA_VERSION` bumps, register the matching migration in
## SaveMigrations._migrations and ship a fixture under test/fixtures/save/.

const SCHEMA_VERSION := 3   # bump on every breaking change

@export var schema_version: int = SCHEMA_VERSION
@export var timestamp: int = 0
@export var play_time_seconds: float = 0.0
@export var current_scene: String = ""
@export var entries: Dictionary[NodePath, Variant] = {}

# v3 added: difficulty preset (was inferred from world flags before)
@export var difficulty: StringName = &"normal"

func assert_valid() -> void:
    assert(schema_version == SCHEMA_VERSION, "save not migrated to current schema")
    assert(timestamp > 0, "missing timestamp")
    assert(difficulty in [&"easy", &"normal", &"hard"], "invalid difficulty: %s" % difficulty)
```

### `autoload/save_migrations.gd`

```gdscript
extends Node
## Sequential migration registry. Each entry migrates schema_version=N
## to schema_version=N+1. Migrations run in order — never skip.

const _MIGRATIONS := {
    1: "_v1_to_v2",
    2: "_v2_to_v3",
}

func migrate(data: SaveData) -> SaveData:
    while data.schema_version < SaveData.SCHEMA_VERSION:
        var previous := data.schema_version
        if not _MIGRATIONS.has(previous):
            push_error("no migration registered from schema_version=%d" % previous)
            return null
        var fn := _MIGRATIONS[previous] as String
        callv(fn, [data])    # mutates `data` in place
        # Each migration must advance schema_version by exactly one — never skip,
        # never stay flat. A flat version would loop forever.
        assert(data.schema_version == previous + 1,
            "migration %s left schema_version=%d (expected %d)" % [fn, data.schema_version, previous + 1])
    return data

# v1 → v2: split monolithic `inventory` Dictionary into typed Resource list.
func _v1_to_v2(data: SaveData) -> void:
    var player_path := NodePath("/root/Game/World/Player")
    var entry: Variant = data.entries.get(player_path)
    if entry is Dictionary:
        var legacy_inv: Dictionary = entry.get("inventory", {})
        var migrated: Array[Resource] = []
        for id in legacy_inv:
            var item := load("res://data/items/%s.tres" % id) as ItemData
            if item != null:
                var stack := ItemStack.new()
                stack.item = item
                stack.count = int(legacy_inv[id])
                migrated.append(stack)
            else:
                push_warning("v1→v2: dropping unknown item '%s'" % id)
        entry["inventory"] = migrated
        data.entries[player_path] = entry
    data.schema_version = 2

# v2 → v3: difficulty was inferred from world_flags["hardcore"]; lift to top-level.
func _v2_to_v3(data: SaveData) -> void:
    var world_path := NodePath("/root/Game/World")
    var entry: Variant = data.entries.get(world_path, {})
    var hardcore: bool = entry.get("world_flags", {}).get("hardcore", false) if entry is Dictionary else false
    data.difficulty = &"hard" if hardcore else &"normal"
    data.schema_version = 3
```

### Wire into `SaveManager.load_game`

In the `setup-save-system` template, the `_migrate` stub becomes:

```gdscript
func load_game(slot: int) -> bool:
    # ... existing loading code ...
    var data := load(path) as SaveData
    if data == null:
        load_finished.emit(slot, false)
        return false

    if data.schema_version > SaveData.SCHEMA_VERSION:
        # save is newer than this build — player rolled back; refuse cleanly
        push_error("save schema_version=%d > supported %d (rolled-back build?)" % [data.schema_version, SaveData.SCHEMA_VERSION])
        load_finished.emit(slot, false)
        return false

    if data.schema_version < SaveData.SCHEMA_VERSION:
        data = SaveMigrations.migrate(data)
        if data == null:
            load_finished.emit(slot, false)
            return false

    data.assert_valid()
    # ... rest of loading code ...
```

(`SaveMigrations` is registered as autoload — use the [`create-autoload`](../create-autoload/SKILL.md) skill.)

## Fixture-based regression tests (GUT)

Every released schema version gets a fixture file checked into the repo. The test loads each fixture, runs migration, and asserts the result. **This is the only thing that proves migrations actually work** — a future you cannot reproduce a v1 save by hand once the v1 code is gone.

```
test/fixtures/save/
├── v1.tres          # checked in when v2 ships; never edited again
├── v2.tres          # checked in when v3 ships; never edited again
└── v3.tres          # current
```

`test/unit/test_save_migrations.gd`:

```gdscript
extends GutTest
## Loads each historical save fixture, migrates, and validates.
## Add a new test_v<N>_loads() function every time SCHEMA_VERSION bumps.

func test_v1_loads() -> void:
    var data := load("res://test/fixtures/save/v1.tres") as SaveData
    assert_not_null(data)
    assert_eq(data.schema_version, 1)
    var migrated := SaveMigrations.migrate(data)
    assert_not_null(migrated, "v1 migration returned null")
    assert_eq(migrated.schema_version, SaveData.SCHEMA_VERSION)
    migrated.assert_valid()

func test_v2_loads() -> void:
    var data := load("res://test/fixtures/save/v2.tres") as SaveData
    assert_eq(data.schema_version, 2)
    var migrated := SaveMigrations.migrate(data)
    assert_not_null(migrated)
    assert_eq(migrated.schema_version, SaveData.SCHEMA_VERSION)
    migrated.assert_valid()

func test_future_version_rejected() -> void:
    # A future version cannot be migrated — load_game must refuse.
    var data := SaveData.new()
    data.schema_version = SaveData.SCHEMA_VERSION + 1
    # SaveManager.load_game checks this case and emits load_finished(slot, false)
    # without calling migrate(); the unit test for SaveManager covers that path.
    pass
```

The fixture files are produced by **the build of the game that shipped that version** — when you bump SCHEMA_VERSION, immediately copy the current shipping save into `test/fixtures/save/v<previous>.tres` before merging the bump.

## Workflow when bumping the schema

1. **Decide the change**: rename a field? Add one? Restructure?
2. **Capture a fixture from the previous shipped version** (run the previous binary, save a representative game state, copy the file to `test/fixtures/save/v<prev>.tres`).
3. **Bump `SaveData.SCHEMA_VERSION`** by exactly one.
4. **Add fields** to the Resource with sane `@export` defaults (so a freshly-loaded migrated save is not full of `null`).
5. **Write the migration** (`_v<prev>_to_v<new>`) that mutates a payload of the previous shape into the new shape.
6. **Register the migration** in `SaveMigrations._MIGRATIONS`.
7. **Update `assert_valid()`** with any new invariants the migration is supposed to establish.
8. **Add `test_v<prev>_loads()`** to the migration test suite.
9. **Run the full suite locally** with `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit`.
10. **Update the changelog** with one line: "Save format bumped to v<new>; v<prev> saves migrate automatically".

## Anti-patterns (do not do these)

- ❌ **Skipping migrations**: `if version == 1: data = v1_to_v3(data)` — once v4 ships you have a combinatorial explosion. Always sequential.
- ❌ **Migrating in `SaveManager.load_game` directly**: keeps `SaveManager` short for one version, becomes a 400-line `match` block by v6. Use the registry from day one.
- ❌ **Mutating fixtures retroactively**: a fixture is a *snapshot* of what the game wrote at that version. If a migration breaks because the fixture changed, the fixture is wrong, not the migration.
- ❌ **Letting unknown fields silently pass through**: a Resource ignores unknown fields on load by default, so renaming a field without a migration produces a save with both the old (zeroed) and the new (also zeroed) field. Always migrate.
- ❌ **Storing `Node` instances**: same caveat as in [`setup-save-system`](../setup-save-system/SKILL.md). Migrations cannot rebuild Node references.

## When NOT to bump

- Adding a new optional field that defaults sensibly for old saves and is *purely additive* — many engines ship without a bump in this case. Bumping anyway is cheap and gives you a checkpoint; the cost is a few minutes of fixture work. Default to bumping.
- Reading the same data with a different code path. The save format did not change.

## See also

- [`setup-save-system`](../setup-save-system/SKILL.md) — the underlying SaveManager + SaveData this skill extends
- [`gut-test-writer`](../gut-test-writer/SKILL.md) — pattern for the fixture-based regression test
- [Saving games (official)](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
