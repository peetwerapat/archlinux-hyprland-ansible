#!/usr/bin/env bash
# -----------------------------------------------------
# Set the wallpaper, remember it, and regenerate the
# Matugen palette so waybar / rofi / swaync / kitty follow.
#
#   wallpaper.sh [/path/to/image]     no arg = re-apply the cached one
# -----------------------------------------------------
set -uo pipefail

CACHE_DIR="$HOME/.cache/wallpaper"
CACHE_FILE="$CACHE_DIR/current"
BLURRED="$CACHE_DIR/blurred.png"
DEFAULT="$HOME/wallpaper/DesktopBG.jpeg"
MATUGEN="$HOME/.cargo/bin/matugen"

mkdir -p "$CACHE_DIR"

# ---- pick the wallpaper ----
wallpaper="${1:-}"
[ -z "$wallpaper" ] && wallpaper="$(cat "$CACHE_FILE" 2>/dev/null)"
[ -f "$wallpaper" ] || wallpaper="$DEFAULT"
echo "$wallpaper" >"$CACHE_FILE"
echo ":: Wallpaper: $wallpaper"

# ---- apply it (hyprpaper) ----
pgrep -x hyprpaper >/dev/null || { hyprpaper >/dev/null 2>&1 & sleep 0.5; }
hyprctl hyprpaper preload "$wallpaper" >/dev/null
hyprctl hyprpaper wallpaper ",$wallpaper" >/dev/null
hyprctl hyprpaper unload unused >/dev/null 2>&1

# ---- blurred copy (used as the wlogout background) ----
if command -v magick >/dev/null 2>&1; then
    magick "$wallpaper" -resize 1920x -blur 0x12 "$BLURRED" 2>/dev/null &
fi

# ---- colors ----
if [ -x "$MATUGEN" ]; then
    echo ":: Running matugen"
    "$MATUGEN" image "$wallpaper" -m dark
fi

# ---- reload whatever reads the palette ----
killall -SIGUSR2 waybar 2>/dev/null
swaync-client --reload-css >/dev/null 2>&1
command -v pywalfox >/dev/null 2>&1 && pywalfox update >/dev/null 2>&1

exit 0
