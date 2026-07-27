#!/usr/bin/env bash
# -----------------------------------------------------
# Toggle the NetworkManager tray applet
#
#   nm-applet.sh          start it
#   nm-applet.sh stop     stop it
#   nm-applet.sh toggle   flip it
# -----------------------------------------------------
set -uo pipefail

case "${1:-start}" in
stop)
    killall nm-applet
    ;;
toggle)
    if pgrep -x nm-applet >/dev/null; then
        killall nm-applet
    else
        nm-applet --indicator &
    fi
    ;;
*)
    pgrep -x nm-applet >/dev/null || nm-applet --indicator &
    ;;
esac
