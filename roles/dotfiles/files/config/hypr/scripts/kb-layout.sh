#!/usr/bin/env bash
# -----------------------------------------------------
# Active keyboard layout as an UPPERCASE code, for waybar.
#
# waybar's own hyprland/language module only renders the
# lowercase xkb short name and its format-<lang> override is
# broken in this build, so this prints the label directly and
# then follows Hyprland's event socket (no polling).
# -----------------------------------------------------
set -uo pipefail

label() {
    case "${1,,}" in
    *thai*) echo "TH" ;;
    *english*) echo "US" ;;
    *) echo "${1:0:2}" | tr '[:lower:]' '[:upper:]' ;;
    esac
}

current() {
    hyprctl devices -j 2>/dev/null |
        jq -r 'first(.keyboards[] | select(.main == true)) // .keyboards[0] | .active_keymap' 2>/dev/null
}

label "$(current)"

SOCK="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
[ -S "$SOCK" ] || exit 0

ncat -U "$SOCK" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
    activelayout\>\>*) label "${line##*,}" ;;
    esac
done
