#!/usr/bin/env bash
# -----------------------------------------------------
# Volume dropdown for waybar — drops under the bar,
# same theme as the launcher.
# -----------------------------------------------------
set -uo pipefail

source "$HOME/.config/hypr/scripts/lib-dropdown.sh"
SINK="@DEFAULT_SINK@"

# clicking the module again closes the panel
dropdown_toggle_guard

vol=$(pactl get-sink-volume "$SINK" | awk 'NR==1 {print $5}' | tr -d '%')
muted=$(pactl get-sink-mute "$SINK" | awk '{print $2}')
name=$(pactl list sinks | awk -v s="$(pactl get-default-sink)" '
    /^Sink #/ {cur=""} /Name: / {cur=$2}
    /Description: / {sub(/^\s*Description: /,""); if (cur==s) {print; exit}}')

if [ "$muted" = "yes" ]; then
    header="󰝟   Muted"
else
    header="󰕾   ${vol}%"
fi

entries=""
if [ "$muted" = "yes" ]; then
    entries+="󰕾   Unmute\n"
else
    entries+="󰝟   Mute\n"
fi
entries+="󰝝   Volume up   +5%\n"
entries+="󰝞   Volume down   −5%\n"
entries+="󰕾   Set to 25%\n"
entries+="󰕾   Set to 50%\n"
entries+="󰕾   Set to 75%\n"
entries+="󰕾   Set to 100%\n"
entries+="󰤽   Output: ${name:-default}\n"
entries+="󰓃   Open mixer"

dropdown_watch
choice=$(echo -e "$entries" | dropdown_menu "$header" -no-custom \
    -theme-str 'entry { placeholder: "Search"; }')
dropdown_stop_watch

case "$choice" in
*"Unmute"* | *"Mute"*) pactl set-sink-mute "$SINK" toggle ;;
*"Volume up"*) pactl set-sink-mute "$SINK" 0 && pactl set-sink-volume "$SINK" +5% ;;
*"Volume down"*) pactl set-sink-mute "$SINK" 0 && pactl set-sink-volume "$SINK" -5% ;;
*"Set to 25%"*) pactl set-sink-mute "$SINK" 0 && pactl set-sink-volume "$SINK" 25% ;;
*"Set to 50%"*) pactl set-sink-mute "$SINK" 0 && pactl set-sink-volume "$SINK" 50% ;;
*"Set to 75%"*) pactl set-sink-mute "$SINK" 0 && pactl set-sink-volume "$SINK" 75% ;;
*"Set to 100%"*) pactl set-sink-mute "$SINK" 0 && pactl set-sink-volume "$SINK" 100% ;;
*"Output:"*)
    # cycle to the next available sink
    mapfile -t sinks < <(pactl -f json list sinks | jq -r '.[].name')
    current=$(pactl get-default-sink)
    next="${sinks[0]}"
    for i in "${!sinks[@]}"; do
        if [ "${sinks[$i]}" = "$current" ]; then
            next="${sinks[$(((i + 1) % ${#sinks[@]}))]}"
            break
        fi
    done
    pactl set-default-sink "$next"
    notify-send "Audio output" "$(pactl list sinks | awk -v s="$next" '/^Sink #/{cur=""} /Name: /{cur=$2} /Description: /{sub(/^\s*Description: /,""); if (cur==s) {print; exit}}')"
    ;;
*"Open mixer"*) pavucontrol & ;;
esac
