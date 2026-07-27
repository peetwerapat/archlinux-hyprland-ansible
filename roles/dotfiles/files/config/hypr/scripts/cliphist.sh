#!/usr/bin/env bash
# -----------------------------------------------------
# Clipboard history through rofi
#
#   cliphist.sh      pick an entry and copy it
#   cliphist.sh d    pick an entry and delete it
#   cliphist.sh w    wipe the whole history (asks first)
# -----------------------------------------------------
set -uo pipefail

case "${1:-}" in
d)
    cliphist list | rofi -dmenu -replace -config ~/.config/rofi/config-cliphist.rasi | cliphist delete
    ;;
w)
    answer=$(printf 'Clear\nCancel\n' | rofi -dmenu -config ~/.config/rofi/config-short.rasi -p "Clipboard")
    [ "$answer" = "Clear" ] && cliphist wipe
    ;;
*)
    cliphist list | rofi -dmenu -replace -config ~/.config/rofi/config-cliphist.rasi | cliphist decode | wl-copy
    ;;
esac
