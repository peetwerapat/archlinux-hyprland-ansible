#!/usr/bin/env bash
# -----------------------------------------------------
# Restore the last wallpaper at login (no palette rebuild —
# the generated color files are already on disk).
# -----------------------------------------------------
set -uo pipefail

CACHE_FILE="$HOME/.cache/wallpaper/current"
DEFAULT="$HOME/wallpaper/DesktopBG.jpeg"

wallpaper="$(cat "$CACHE_FILE" 2>/dev/null)"
[ -f "$wallpaper" ] || wallpaper="$DEFAULT"

echo ":: Restoring wallpaper $wallpaper"
pgrep -x hyprpaper >/dev/null || { hyprpaper >/dev/null 2>&1 & sleep 0.5; }
hyprctl hyprpaper preload "$wallpaper" >/dev/null
hyprctl hyprpaper wallpaper ",$wallpaper" >/dev/null
