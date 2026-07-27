#!/usr/bin/env bash
# -----------------------------------------------------
# wlogout, sized to the focused monitor
# -----------------------------------------------------
set -uo pipefail

read -r res_w res_h scale < <(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | "\(.width) \(.height) \(.scale)"')
mv=$(awk -v h="$res_h" -v s="$scale" 'BEGIN { printf "%d", (h / s) * 0.33 }')
mh=$(awk -v w="$res_w" -v s="$scale" 'BEGIN { printf "%d", (w / s) * 0.13 }')

exec wlogout -b 5 -T "$mv" -B "$mv" -L "$mh" -R "$mh"
