#!/usr/bin/env python3
"""Waybar custom module: Magic Trackpad battery.

Renders the state written by the magic-trackpad-battery daemon
($XDG_RUNTIME_DIR/magic-trackpad-battery.json), but only while the
trackpad is actually connected over Bluetooth.

The daemon only re-checks every 300s, so its "connected" flag lingers for
minutes after the trackpad goes away. We probe /sys/class/hidraw directly
instead, which reflects the Bluetooth link immediately.
"""

import html
import json
import os
import time

ICON = "\U000F0638"          # nf-md-gesture (hand / tap)
CHARGING_ICON = ""          # same bolt the built-in battery module uses
GAP = "   "                  # icon/value gap used by the other right-island modules
MAX_STATE_AGE = 400          # seconds; daemon polls every 300

HIDDEN = {"text": ""}


def bluetooth_connected():
    """True when a Bluetooth Magic Trackpad is bound to the magicmouse driver.

    Mirrors the daemon's find_hidraw(): DRIVER=magicmouse, a Bluetooth bus id
    (0005:) and a "magic trackpad" product name.
    """
    try:
        entries = os.listdir("/sys/class/hidraw")
    except OSError:
        return False

    for entry in entries:
        driver = False
        hid_id = hid_name = None
        try:
            with open(f"/sys/class/hidraw/{entry}/device/uevent") as uevent:
                for line in uevent:
                    line = line.strip()
                    if line == "DRIVER=magicmouse":
                        driver = True
                    elif line.startswith("HID_ID="):
                        hid_id = line.split("=", 1)[1]
                    elif line.startswith("HID_NAME="):
                        hid_name = line.split("=", 1)[1]
        except OSError:
            continue

        if (
            driver
            and hid_id is not None
            and hid_id.startswith("0005:")
            and hid_name is not None
            and "magic trackpad" in hid_name.casefold()
        ):
            return True
    return False


def read_state():
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime_dir:
        return None
    try:
        with open(os.path.join(runtime_dir, "magic-trackpad-battery.json")) as state:
            return json.load(state)
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None


def render(state, connected, now=None):
    if not connected or not isinstance(state, dict):
        return HIDDEN

    percentage = state.get("percentage")
    charging = state.get("charging")
    device_name = state.get("device_name")
    updated_at = state.get("updated_at")
    if (
        type(percentage) is not int
        or not 0 <= percentage <= 100
        or type(charging) is not bool
        or type(updated_at) is not int
    ):
        return HIDDEN

    # A reading older than the daemon's poll interval is not trustworthy.
    if now is None:
        now = int(time.time())
    if not 0 <= now - updated_at <= MAX_STATE_AGE:
        return HIDDEN

    if charging:
        css_class = "charging"
    elif percentage <= 20:
        css_class = "critical"
    elif percentage <= 40:
        css_class = "warning"
    else:
        css_class = ""

    icon = f"{ICON} {CHARGING_ICON}" if charging else ICON
    if not isinstance(device_name, str):
        device_name = "Magic Trackpad"
    tooltip = f"{html.escape(device_name)}: {percentage}%"
    if charging:
        tooltip += " (charging)"

    return {
        "text": f"{icon}{GAP}{percentage}%",
        "class": css_class,
        "tooltip": tooltip,
    }


def main():
    print(json.dumps(render(read_state(), bluetooth_connected())))


if __name__ == "__main__":
    main()
