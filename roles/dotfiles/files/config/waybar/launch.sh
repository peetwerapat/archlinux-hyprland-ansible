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

# Restart waybar if it crashes (its pulseaudio module segfaults when the
# D6000/HDMI audio devices hotplug). A normal kill (killall -> SIGTERM) stops the loop.
(
    while true; do
        waybar -c "$CONFIG_DIR/config.jsonc" -s "$CONFIG_DIR/style.css"
        rc=$?
        # 134 = SIGABRT, 139 = SIGSEGV
        [ "$rc" -eq 134 ] || [ "$rc" -eq 139 ] || break
        sleep 1
    done
) &
