---
name: setup-localization
description: Set up Godot 4.x localization (i18n) for a project — CSV translation tables, gettext .po workflow, language switcher, locale persistence, font fallback for non-Latin scripts. Use to add multi-language support, change UI language at runtime, or wire fonts that cover languages outside the default Latin set.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: <comma-separated-locales>
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Setup Localization

Wires the full i18n pipeline in Godot 4.x: CSV-based translations (best for short UI strings), optional `.po`/`gettext` for long-form text, runtime language switcher, locale persistence in `user://settings.cfg`, and font fallback for scripts the default font does not cover.

Reference: [Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html), [Locales](https://docs.godotengine.org/en/stable/tutorials/i18n/locales.html), [Importing translations](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_translations.html).

## Decision: CSV vs gettext (.po)

| Use **CSV** when | Use **.po (gettext)** when |
|---|---|
| Short UI strings (menus, HUD, button labels) | Long narrative / dialogue paragraphs |
| Translators are non-technical (work in spreadsheets) | Translators use gettext-aware tooling (Poedit, Crowdin) |
| Project has < ~500 strings | Project has many strings, plurals, contextual variants |

Both can coexist: CSV for UI, `.po` for in-game prose / dialogue.

## CSV pipeline

### 1. Create `localization/translations.csv`

```csv
keys,en,it,fr,ja
ui.menu.start,Start,Inizia,Démarrer,スタート
ui.menu.options,Options,Opzioni,Options,設定
ui.menu.quit,Quit,Esci,Quitter,終了
hud.score,Score: %d,Punteggio: %d,Score : %d,スコア: %d
dialogue.npc.greet,Hello traveler.,Salve viaggiatore.,Bonjour voyageur.,こんにちは、旅人。
```

Rules:
- Column 1 header = `keys`. First row = column header (each cell after `keys` is a [BCP-47 locale code](https://docs.godotengine.org/en/stable/tutorials/i18n/locales.html)).
- Keys use namespaced dot.case (`area.subarea.name`) — never raw English. Switching the source language later then costs nothing.
- Use `%s`, `%d`, `%.2f` placeholders for runtime substitution: `tr("hud.score") % score`.

### 2. Import the CSV

In **Project → Project Settings → Localization → Translations**, click *Add* and select `localization/translations.csv`. Godot generates one `.translation` file per language under the same folder (these are imported assets — do not edit by hand).

In `project.godot` this lands as:

```ini
[internationalization]

locale/translations=PackedStringArray("res://localization/translations.en.translation", "res://localization/translations.it.translation", "res://localization/translations.fr.translation", "res://localization/translations.ja.translation")
locale/fallback="en"
```

Add `*.translation` to `.gitignore` if you commit the source CSV — they regenerate on import. (See `bootstrap-godot-project` for the standard `.gitignore`.)

### 3. Use translations at runtime

```gdscript
# In any node:
$Label.text = tr("ui.menu.start")
$ScoreLabel.text = tr("hud.score") % current_score

# For text set in the editor, prefix with the same key — Godot will translate automatically:
# Label.text = "ui.menu.start"  (auto-translate enabled by default on Control nodes)
```

`tr()` falls back to the **key itself** if the lookup fails. That makes missing keys obvious during testing — keys leak into the UI literally, instead of crashing.

For plural forms, use `tr_n()`:

```gdscript
# CSV row: ui.enemies_remaining,"%d enemy left","%d enemies left"  (English plural rule)
$Label.text = tr_n("ui.enemies_remaining", "ui.enemies_remaining", count) % count
```

## gettext (.po) pipeline

For long-form text (dialogue, lore, item flavor):

```bash
# Generate POT template from source code
godot --headless --path . --quit-after 1 \
    --export-translation-pot localization/messages.pot

# Translators work on per-language .po files
msginit --input=localization/messages.pot --locale=it --output=localization/it.po
# ... translators edit it.po ...

# Compile .po → .mo (or import the .po directly in Godot 4)
```

In **Project Settings → Localization → Translations**, add the `.po` files alongside the CSV `.translation` files. Godot resolves `tr()` against the union of both.

## Runtime language switcher

`scripts/ui/language_switcher.gd`:

```gdscript
extends OptionButton

const LANG_KEY := "language"
const SETTINGS_PATH := "user://settings.cfg"

# (BCP-47 code, native-name) — native names are intentional: a French speaker
# looking for French scans the list for "Français", not "French".
const LANGUAGES: Array[Array] = [
    ["en", "English"],
    ["it", "Italiano"],
    ["fr", "Français"],
    ["ja", "日本語"],
]


func _ready() -> void:
    for entry in LANGUAGES:
        add_item(entry[1])
    item_selected.connect(_on_selected)
    _select_current()


func _select_current() -> void:
    var current := TranslationServer.get_locale()
    for i in LANGUAGES.size():
        if current.begins_with(LANGUAGES[i][0]):
            select(i)
            return
    select(0)


func _on_selected(idx: int) -> void:
    var locale: String = LANGUAGES[idx][0]
    TranslationServer.set_locale(locale)
    var cfg := ConfigFile.new()
    cfg.load(SETTINGS_PATH)
    cfg.set_value("locale", LANG_KEY, locale)
    cfg.save(SETTINGS_PATH)
    get_tree().reload_current_scene()  # forces all `tr()` calls to refresh
```

Apply the saved locale at boot — add to `autoload/game_state.gd` (or wherever you bootstrap settings):

```gdscript
func _ready() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://settings.cfg") == OK:
        var locale: String = cfg.get_value("locale", "language", OS.get_locale())
        TranslationServer.set_locale(locale)
```

`OS.get_locale()` returns the user's system locale on first run — sane default for users who never touch the language menu.

## Font fallback for non-Latin scripts

Default Godot fonts cover Latin only. For Japanese / Chinese / Korean / Cyrillic / Arabic / Hindi, register fallback fonts on the **Theme**, not on every Label:

1. Project root: `assets/fonts/main.ttf` (Latin), `assets/fonts/jp.otf` (CJK), `assets/fonts/ar.ttf` (Arabic), …
2. Open the project's main `Theme` resource (`themes/main_theme.tres`).
3. On `Label`, `Button`, `RichTextLabel` font properties: set the primary `FontFile`, then add `FontFile`s as **fallbacks** in order. Godot picks the first font whose glyph set covers the codepoint.
4. For RTL languages (Arabic, Hebrew), set `Label.text_direction = TEXT_DIRECTION_AUTO` and verify your layouts mirror correctly. Use `Control.layout_direction = LAYOUT_DIRECTION_LOCALE` on container roots so margins flip with the locale.

## Pre-release checklist

- [ ] Every UI string goes through `tr()` (or auto-translate). No raw English in `.gd` or `.tscn` for shipped text.
- [ ] CSV / `.po` covers all listed locales — no missing rows. (Empty cell = falls back to `locale/fallback`.)
- [ ] Plurals use `tr_n()`, not `if count == 1: ...`.
- [ ] Locale persists across sessions (verify by changing language → quit → relaunch).
- [ ] Non-Latin locales render glyphs (no tofu boxes □□□).
- [ ] RTL locales mirror layouts correctly if shipping Arabic / Hebrew.
- [ ] Date / number formatting uses `Time.get_date_string_from_system()` and locale-aware string formatting where it matters.

## Common pitfalls

- **Hardcoded English in `.tscn`**: `Label.text = "Start"` ships untranslated. Replace with key `ui.menu.start`; auto-translate handles the lookup.
- **Concatenating translated strings**: `tr("ui.you_have") + str(score) + tr("ui.points")` breaks word order in non-English. Use a single key with `%s` placeholders.
- **Reloading scenes on every change**: `reload_current_scene()` is the simplest way to refresh `tr()` calls, but loses player state. For in-game language switches mid-run, walk the tree and re-run `tr()` on every `Label`/`RichTextLabel`, or trigger a custom `language_changed` signal that nodes subscribe to.
- **Locale codes**: use BCP-47 (`pt-BR`, not `pt_br`). Godot accepts both forms but BCP-47 is the standard the rest of the world uses.
