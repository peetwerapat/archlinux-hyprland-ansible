#!/usr/bin/env bash
# -----------------------------------------------------
# Shared hyprpaper helpers.
#
# hyprpaper 0.8 replaced its IPC: only `wallpaper` and
# `listactive` survive, `preload`/`unload`/`listloaded` now
# answer "invalid hyprpaper request". Wallpapers are loaded
# on demand, so setting one is a single call.
# -----------------------------------------------------

# Start hyprpaper if needed and wait until its IPC answers.
ensure_hyprpaper() {
    pgrep -x hyprpaper >/dev/null || hyprpaper >/dev/null 2>&1 &

    for _ in $(seq 1 50); do        # up to ~5s
        hyprctl hyprpaper listactive >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    return 1
}

# apply_wallpaper <path>   sets it on every output
# (a per-monitor rule would win over this wildcard, so we never set one)
apply_wallpaper() {
    local path="$1" active

    ensure_hyprpaper || { echo ":: hyprpaper IPC never came up" >&2; return 1; }

    for _ in $(seq 1 20); do        # outputs can appear slightly after the IPC
        hyprctl hyprpaper wallpaper ",$path" >/dev/null 2>&1
        active="$(hyprctl hyprpaper listactive 2>/dev/null)"
        [ -n "$active" ] && ! grep -qvF "$path" <<<"$active" && return 0
        sleep 0.25
    done
    return 1
}
