#!/usr/bin/env bash
# Watch the gestures libinput feeds into Hyprland, live.
# Usage: ~/.config/hypr/scripts/gesture-debug.sh   then swipe on the trackpad
LOG=$(ls -t /run/user/$UID/hypr/*/hyprland.log 2>/dev/null | head -1)
[ -z "$LOG" ] && { echo "hyprland.log not found"; exit 1; }
echo "watching: $LOG"
echo "swipe with 3/4 fingers on the trackpad (Ctrl+C to quit)"
echo "---"
tail -f "$LOG" | grep --line-buffered -oE "\[[0-9]fg\] .*GESTURE_STATE_(SWIPE|PINCH)[A-Z_]*"
