#!/usr/bin/env bash
# SessionStart — print Godot version + warn if gdtoolkit is missing.
set -u

if command -v godot >/dev/null 2>&1; then
    v=$(godot --version 2>/dev/null | head -1)
    echo "godot: $v"
    case "$v" in
        4.3*|4.4*|4.5*|4.6*) ;;
        4.*) echo 'note: godot-superpowers targets 4.3+. Some skills (TileMapLayer, Parallax2D) require 4.3+.' ;;
        *) echo 'warn: Godot < 4.x detected. Use the gdscript-migrator agent.' ;;
    esac
else
    echo 'note: godot CLI not on PATH'
fi

if ! command -v gdformat >/dev/null 2>&1; then
    echo 'note: gdtoolkit not installed. pipx install gdtoolkit==4.*'
fi
