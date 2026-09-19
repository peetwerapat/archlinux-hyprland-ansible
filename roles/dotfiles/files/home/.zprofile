
# Created by `pipx` on 2025-05-17 14:26:22
export PATH="$PATH:/home/peet/.local/bin"

# Hyprland + Dell D6000 (DisplayLink/evdi): must be set before Hyprland starts,
# `env =` in hyprland.conf is applied too late for aquamarine.
#
# AQ_NO_ATOMIC: less flicker on the LG over DisplayLink, but every hotplug
# of the dock freezes for ~30s (evdi re-modeset loop). Comment it out if
# the LG goes back to laptop HDMI.
export AQ_NO_ATOMIC=1
export AQ_MGPU_NO_EXPLICIT=1
