#!/usr/bin/env bash
# -----------------------------------------------------
# Shared helpers for the waybar dropdown panels
# (volume-menu.sh, wifi-menu.sh).
#
# Closing the panel by clicking outside it cannot be done with
# rofi's own click-to-exit: on Wayland rofi is a layer surface
# with exclusive keyboard focus, so clicks landing on another
# window never reach it and often do not even change the active
# window. Two watchers cover it instead:
#
#   1. pointer  — once the pointer has been inside the panel,
#                 leaving it for longer than the debounce closes
#                 the panel (you have to move out there to click).
#   2. compositor events — switching window, workspace or monitor
#                 closes it too.
# -----------------------------------------------------

ROFI_CFG="$HOME/.config/rofi/config-dropdown.rasi"
DROPDOWN_WATCHERS=()

_hypr_socket() {
    printf '%s/hypr/%s/.socket2.sock' "$XDG_RUNTIME_DIR" "$HYPRLAND_INSTANCE_SIGNATURE"
}

# close on window / workspace / monitor changes
_watch_events() {
    local sock
    sock="$(_hypr_socket)"
    [ -S "$sock" ] || return 0
    (
        ncat --recv-only -U "$sock" 2>/dev/null | while IFS= read -r line; do
            case "$line" in
            activewindow\>\>* | workspace\>\>* | focusedmon\>\>*)
                pkill -x rofi
                break
                ;;
            esac
        done
    ) &
    DROPDOWN_WATCHERS+=("$!")
}

# close once the pointer has entered the panel and then left it
_watch_pointer() {
    (
        local margin=14 debounce=4 outside=0 entered=0
        local x y lx ly lw lh geo

        while pgrep -x rofi >/dev/null; do
            geo=$(hyprctl layers -j 2>/dev/null |
                jq -r 'first(.[].levels[][] | select(.namespace == "rofi")) | "\(.x) \(.y) \(.w) \(.h)"' 2>/dev/null)
            [ -z "$geo" ] || [ "$geo" = "null" ] && {
                sleep 0.2
                continue
            }
            read -r lx ly lw lh <<<"$geo"
            read -r x y < <(hyprctl cursorpos 2>/dev/null | tr -d ',')

            if [ -n "${x:-}" ] &&
                [ "$x" -ge $((lx - margin)) ] && [ "$x" -le $((lx + lw + margin)) ] &&
                [ "$y" -ge $((ly - margin)) ] && [ "$y" -le $((ly + lh + margin)) ]; then
                entered=1
                outside=0
            elif [ "$entered" -eq 1 ]; then
                outside=$((outside + 1))
                [ "$outside" -ge "$debounce" ] && {
                    pkill -x rofi
                    break
                }
            fi
            sleep 0.15
        done
    ) &
    DROPDOWN_WATCHERS+=("$!")
}

dropdown_watch() {
    _watch_events
    _watch_pointer
}

dropdown_stop_watch() {
    local pid
    for pid in "${DROPDOWN_WATCHERS[@]}"; do
        kill "$pid" 2>/dev/null
    done
    DROPDOWN_WATCHERS=()
}

# clicking the waybar module again closes an open panel
dropdown_toggle_guard() {
    if pgrep -x rofi >/dev/null; then
        pkill -x rofi
        exit 0
    fi
}

# entries on stdin, status header as $1, extra rofi args after that
dropdown_menu() {
    local mesg="$1"
    shift
    rofi -dmenu -i -config "$ROFI_CFG" \
        -location 3 -xoffset -14 -yoffset 58 -p "" -mesg "$mesg" "$@"
}
