#!/usr/bin/env bash
# -----------------------------------------------------
# (Re)start waybar with ~/.config/waybar/config.jsonc
# Skipped while the "disabled" flag file exists.
# -----------------------------------------------------
set -uo pipefail

CONFIG_DIR="$HOME/.config/waybar"

killall waybar 2>/dev/null
sleep 0.3

if [ -f "$CONFIG_DIR/disabled" ]; then
    echo ":: Waybar disabled"
    exit 0
fi

waybar -c "$CONFIG_DIR/config.jsonc" -s "$CONFIG_DIR/style.css" &
