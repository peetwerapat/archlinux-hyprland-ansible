#!/usr/bin/env bash
# -----------------------------------------------------
# Gamemode: drop every effect for maximum frames,
# toggle again to reload the normal config.
# -----------------------------------------------------
set -uo pipefail

STATE="$HOME/.cache/hypr/gamemode"
mkdir -p "$(dirname "$STATE")"

if [ -f "$STATE" ]; then
    rm -f "$STATE"
    hyprctl reload >/dev/null
    notify-send "Gamemode off" "Animations, blur and gaps are back"
else
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0" >/dev/null
    touch "$STATE"
    notify-send "Gamemode on" "Animations, blur and gaps disabled"
fi
