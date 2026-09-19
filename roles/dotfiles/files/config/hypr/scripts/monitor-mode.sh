#!/usr/bin/env bash

set -u

MODE="${1:-}"

# =====================================================
# Monitors
#
# External monitors are found by the EDID the kernel reads
# (/sys/class/drm/*/edid), not by connector name:
#  - DisplayLink (Dell D6000 / evdi) names change on every
#    replug (DVI-I-1, DVI-I-2, ...)
#  - after a hotplug Hyprland can keep a stale description
#    for a connector, so desc: matching is not reliable either
#
# Mode B's top monitor is the exception: it is whatever is
# plugged into the laptop HDMI port.
# =====================================================

LAPTOP="eDP-1"
MAIN_EDID="27GL850"   # LG 27GL850
SIDE_EDID="S24R35x"   # Samsung S24R35x
TOP="HDMI-A-2"        # mode B top

find_connector() {
    local product="$1"
    local c

    for c in /sys/class/drm/card*-*; do
        [ "$(cat "$c/status" 2>/dev/null)" = "connected" ] || continue

        if grep -aq "$product" "$c/edid" 2>/dev/null; then
            basename "$c" | sed 's/^card[0-9]*-//'
            return
        fi
    done
}

# Best mode a monitor advertises as "<width> <height> <refresh>":
# most pixels, and among those the highest refresh rate.
# Prints nothing when the monitor is not connected.
best_mode() {
    hyprctl monitors all -j | jq -r --arg name "$1" '
        [ .[] | select(.name == $name) | .availableModes[]
          | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)")
          | { w: (.w | tonumber), h: (.h | tonumber), r: (.r | tonumber) } ]
        | sort_by(.w * .h, .r)
        | last
        | if . then "\(.w) \(.h) \(.r)" else empty end
    '
}

MAIN=""
SIDE=""

# Only modes A-D call this. Mode E never scans connectors / EDID.
detect_monitors() {
    MAIN="$(find_connector "$MAIN_EDID")"
    SIDE="$(find_connector "$SIDE_EDID")"

    case "$MAIN" in
        DVI-I-*) MAIN_FAST_RES="1920x1080@60" ;;
        *)       MAIN_FAST_RES="1920x1080@120" ;;
    esac
}

# =====================================================
# Resolutions
#
# DisplayLink cannot keep up above 60Hz (flicker), so
# anything on DVI-I-* stays at 60Hz.
# =====================================================

LAPTOP_RES="1920x1080@60"
SIDE_RES="1920x1080@60"

MAIN_NATIVE_RES="2560x1440@59.95"
MAIN_FAST_RES="1920x1080@120"

SCALE="1"


# =====================================================
# Helpers
#
# All monitor rules of a mode are sent in one hyprctl
# --batch, and monitors that stay on are never disabled
# first: every extra modeset on DisplayLink is a visible
# freeze/flicker.
# =====================================================

BATCH=()

set_monitor() {
    local name="$1"
    local config="$2"

    [ -n "$name" ] || return 0

    echo "[monitor] $name -> $config"

    BATCH+=("keyword monitor $name,$config")
}

disable_monitor() {
    local name="$1"

    [ -n "$name" ] || return 0

    echo "[monitor] $name -> disabled"

    BATCH+=("keyword monitor $name,disable")
}

apply_layout() {
    local focus="$1"
    local cmds

    cmds="$(printf '%s ; ' "${BATCH[@]}")"
    hyprctl --batch "$cmds" >/dev/null

    [ -n "$focus" ] && hyprctl dispatch focusmonitor "$focus" >/dev/null
}

notify_mode() {
    local mode="$1"
    local description="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send \
            -a "Hyprland" \
            -t 1500 \
            "Monitor Mode $mode" \
            "$description"
    fi
}

# Rules that mode E overrides with "disable" so hotplugged
# monitors stay off. Modes A-D put them back to the
# monitors.conf defaults before adding their own rules
# (later rules win over earlier ones).
MAIN_DESC="desc:LG Electronics 27GL850 009INRC1C502"
SIDE_DESC="desc:Samsung Electric Company S24R35x H4TMA01205"

restore_default_rules() {
    BATCH+=("keyword monitor ,preferred,auto,1")
    BATCH+=("keyword monitor ${MAIN_DESC},${MAIN_NATIVE_RES},0x0,${SCALE}")
    BATCH+=("keyword monitor ${SIDE_DESC},preferred,auto,${SCALE}")
}

header() {
    echo
    echo "========================================"
    echo "MODE $1  (LG=${MAIN:-none}, Samsung=${SIDE:-none})"
    echo "========================================"
}

# detect + reset rules, shared by modes A-D
begin_mode() {
    detect_monitors
    header "$1"
    restore_default_rules
}


# =====================================================
# MODE A
#
# Samsung = LEFT + VERTICAL
# LG      = MAIN / 2560x1440 @ 59.95Hz
# eDP-1   = RIGHT
#
# ┌──────┐ ┌──────────────────────────┐ ┌────────────────┐
# │      │ │                          │ │                │
# │ S24  │ │        LG 27GL850        │ │     eDP-1      │
# │  ↕   │ │     2560x1440 @ 60       │ │    1920x1080   │
# │      │ │          MAIN            │ │                │
# └──────┘ └──────────────────────────┘ └────────────────┘
#
# Samsung = -1080x0
# LG      = 0x0
# eDP     = 2560x0
# =====================================================

mode_a() {

    begin_mode "A"

    set_monitor "$LAPTOP" "${LAPTOP_RES},2560x0,${SCALE}"
    set_monitor "$MAIN"   "${MAIN_NATIVE_RES},0x0,${SCALE}"
    # transform 1 = 90° rotation, 1920x1080 becomes logical 1080x1920
    set_monitor "$SIDE"   "${SIDE_RES},-1080x0,${SCALE},transform,1"

    apply_layout "$MAIN"

    notify_mode \
        "A" \
        "LG 1440p main • Samsung left vertical • eDP right"
}


# =====================================================
# MODE B
#
# HDMI-A-2 = TOP, at its best mode
# eDP-1    = MAIN / bottom, focused
# LG       = OFF
# Samsung  = OFF
#
# ┌────────────────┐
# │    HDMI-A-2    │   0x-<height>
# └────────────────┘
# ┌────────────────┐
# │     eDP-1      │   0x0   MAIN
# │   1920x1080    │
# └────────────────┘
# =====================================================

mode_b() {

    local w h r
    local top_res="preferred"
    local top_h=1080

    begin_mode "B"

    read -r w h r <<<"$(best_mode "$TOP")"

    if [ -n "${w:-}" ]; then
        top_res="${w}x${h}@${r}"
        top_h="$h"
    fi

    # skip the LG if it is the HDMI-A-2 monitor itself
    [ "$MAIN" = "$TOP" ] || disable_monitor "$MAIN"
    disable_monitor "$SIDE"
    set_monitor "$LAPTOP" "${LAPTOP_RES},0x0,${SCALE}"
    set_monitor "$TOP"    "${top_res},0x-${top_h},${SCALE}"

    apply_layout "$LAPTOP"

    notify_mode \
        "B" \
        "eDP main • ${TOP} top"
}


# =====================================================
# MODE C
#
# Samsung = TOP
# eDP-1   = MAIN
# LG      = OFF
# =====================================================

mode_c() {

    begin_mode "C"

    disable_monitor "$MAIN"
    set_monitor "$LAPTOP" "${LAPTOP_RES},0x0,${SCALE}"
    set_monitor "$SIDE"   "${SIDE_RES},0x-1080,${SCALE}"

    apply_layout "$LAPTOP"

    notify_mode \
        "C" \
        "eDP main • Samsung top"
}


# =====================================================
# MODE D
#
# eDP-1   = MAIN
# Samsung = RIGHT
# LG      = OFF
# =====================================================

mode_d() {

    begin_mode "D"

    disable_monitor "$MAIN"
    set_monitor "$LAPTOP" "${LAPTOP_RES},0x0,${SCALE}"
    set_monitor "$SIDE"   "${SIDE_RES},1920x0,${SCALE}"

    apply_layout "$LAPTOP"

    notify_mode \
        "D" \
        "eDP main • Samsung right"
}


# =====================================================
# MODE E
#
# eDP-1 = ONLY
# every other monitor = OFF
#
# No detection at all: no EDID / sysfs scan. Monitors are
# disabled by the names Hyprland already knows, and the
# fallback + desc: rules are set to "disable" so anything
# hotplugged afterwards is not auto-enabled either.
# Switch to A-D (or reload Hyprland) to undo.
#
# ┌────────────────┐
# │     eDP-1      │
# │   1920x1080    │
# └────────────────┘
# =====================================================

mode_e() {

    local name

    echo
    echo "========================================"
    echo "MODE E  (eDP-1 only)"
    echo "========================================"

    BATCH+=("keyword monitor ,disable")
    BATCH+=("keyword monitor ${MAIN_DESC},disable")
    BATCH+=("keyword monitor ${SIDE_DESC},disable")

    for name in $(hyprctl monitors all | awk '/^Monitor /{print $2}'); do
        [ "$name" = "$LAPTOP" ] || disable_monitor "$name"
    done

    # added last so it wins over the rules above
    set_monitor "$LAPTOP" "${LAPTOP_RES},0x0,${SCALE}"

    apply_layout "$LAPTOP"

    notify_mode \
        "E" \
        "eDP only • external monitors off"
}


# =====================================================
# Main
# =====================================================

case "${MODE^^}" in

    A)
        mode_a
        ;;

    B)
        mode_b
        ;;

    C)
        mode_c
        ;;

    D)
        mode_d
        ;;

    E)
        mode_e
        ;;

    *)
        echo
        echo "Usage:"
        echo "  $0 A"
        echo "  $0 B"
        echo "  $0 C"
        echo "  $0 D"
        echo "  $0 E"
        echo
        exit 1
        ;;

esac
