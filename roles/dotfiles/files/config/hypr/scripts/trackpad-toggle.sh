#!/usr/bin/env bash
# -----------------------------------------------------
# Connect / disconnect the Magic Trackpad over Bluetooth.
# Used by the swaync control center toggle button.
#
#   trackpad-toggle.sh status      echo true/false (for update-command)
#   trackpad-toggle.sh true        connect
#   trackpad-toggle.sh false       disconnect
#   trackpad-toggle.sh             flip the current state
# -----------------------------------------------------
set -uo pipefail

MAC="34:B1:EB:ED:14:B1"
NAME="Magic Trackpad"

connected() {
    bluetoothctl info "$MAC" 2>/dev/null | grep -q "Connected: yes"
}

notify() {
    notify-send -a "Trackpad" -i input-touchpad "$1" "$2" 2>/dev/null
}

case "${1:-toggle}" in
    status)
        connected && echo true || echo false
        ;;
    true)
        connected && exit 0
        if bluetoothctl connect "$MAC" >/dev/null 2>&1; then
            notify "$NAME" "Connected"
        else
            notify "$NAME" "Could not connect — is it turned on?"
        fi
        ;;
    false)
        connected || exit 0
        bluetoothctl disconnect "$MAC" >/dev/null 2>&1
        notify "$NAME" "Disconnected"
        ;;
    toggle)
        connected && exec "$0" false || exec "$0" true
        ;;
    *)
        echo "usage: $(basename "$0") [status|true|false|toggle]" >&2
        exit 1
        ;;
esac
