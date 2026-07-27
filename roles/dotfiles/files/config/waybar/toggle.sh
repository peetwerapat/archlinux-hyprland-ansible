#!/usr/bin/env bash
# -----------------------------------------------------
# Show / hide waybar
# -----------------------------------------------------
set -uo pipefail

FLAG="$HOME/.config/waybar/disabled"

if [ -f "$FLAG" ]; then
    rm -f "$FLAG"
else
    touch "$FLAG"
fi

"$HOME/.config/waybar/launch.sh" &
