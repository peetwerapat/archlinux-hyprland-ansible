#!/usr/bin/env bash
# -----------------------------------------------------
# Wi-Fi dropdown for waybar — drops under the bar,
# same theme as the launcher.
# -----------------------------------------------------
set -uo pipefail

source "$HOME/.config/hypr/scripts/lib-dropdown.sh"

rofi_menu() {
    dropdown_menu "$1" -theme-str 'entry { placeholder: "Search networks"; }' "${@:2}"
}

# clicking the module again closes the panel
dropdown_toggle_guard

radio=$(nmcli -t radio wifi)
active=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2 ~ /wireless/ {print $1; exit}')

if [ "$radio" != "enabled" ]; then
    choice=$(printf '󰖩   Turn Wi-Fi on\n󰒓   Network settings' | rofi_menu "󰖪   Wi-Fi is off" -no-custom)
    case "$choice" in
    *"Turn Wi-Fi on"*) nmcli radio wifi on ;;
    *"Network settings"*) nm-connection-editor & ;;
    esac
    exit 0
fi

# --- build the network list -------------------------------------------------
list=$(nmcli --terse --fields IN-USE,SIGNAL,SECURITY,SSID device wifi list |
    awk -F: '
    $4 != "" {
        ssid = $4
        if (seen[ssid]++) next
        sig = $2 + 0
        icon = (sig >= 75) ? "󰤨" : (sig >= 50) ? "󰤥" : (sig >= 25) ? "󰤢" : "󰤟"
        lock = ($3 == "" || $3 == "--") ? "  " : " 󰌾"
        mark = ($1 == "*") ? "  ●" : ""
        printf "%s   %s%s%s\n", icon, ssid, lock, mark
    }')

entries=""
[ -n "$active" ] && entries+="󰅘   Disconnect from ${active}\n"
entries+="$list\n"
entries+="󰑓   Rescan\n"
entries+="󰖪   Turn Wi-Fi off\n"
entries+="󰒓   Network settings"

if [ -n "$active" ]; then
    mesg="󰖩   Connected to ${active}"
else
    mesg="󰖪   Not connected"
fi

dropdown_watch
choice=$(echo -e "$entries" | rofi_menu "$mesg" -no-custom)
dropdown_stop_watch
[ -z "$choice" ] && exit 0

case "$choice" in
*"Disconnect from"*) nmcli connection down "$active" ;;
*"Rescan"*)
    nmcli device wifi rescan >/dev/null 2>&1
    sleep 2
    exec "$0"
    ;;
*"Turn Wi-Fi off"*) nmcli radio wifi off ;;
*"Network settings"*) nm-connection-editor & ;;
*)
    # strip the icon, the lock glyph and the active marker
    ssid=$(echo "$choice" | sed -E 's/^[^ ]+   //; s/ 󰌾//; s/  ●$//')
    [ -z "$ssid" ] && exit 0

    if nmcli connection show "$ssid" >/dev/null 2>&1; then
        nmcli connection up "$ssid" >/dev/null 2>&1 &&
            notify-send "Wi-Fi" "Connected to $ssid" ||
            notify-send -u critical "Wi-Fi" "Could not connect to $ssid"
    else
        pass=$(printf '' | dropdown_menu "󰌾   $ssid" -password -lines 0 \
            -theme-str 'entry { placeholder: "Password"; }')
        if [ -n "$pass" ]; then
            nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1 &&
                notify-send "Wi-Fi" "Connected to $ssid" ||
                notify-send -u critical "Wi-Fi" "Could not connect to $ssid"
        else
            nmcli device wifi connect "$ssid" >/dev/null 2>&1 &&
                notify-send "Wi-Fi" "Connected to $ssid" ||
                notify-send -u critical "Wi-Fi" "Could not connect to $ssid"
        fi
    fi
    ;;
esac
