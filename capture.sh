#!/usr/bin/env bash
# -----------------------------------------------------
# Refresh the dotfiles snapshot in this repo from the live machine.
#
#   bash capture.sh
#
# Captures only configuration — no caches, no .git folders, no app state.
# -----------------------------------------------------
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$REPO/roles/dotfiles/files/config"
HOMEF="$REPO/roles/dotfiles/files/home"

CONFIG_DIRS=(
    hypr waybar rofi swaync kitty wlogout nwg-dock-hyprland
    gtk-3.0 gtk-4.0 qt6ct matugen xsettingsd waypaper fastfetch
    nvim git tmux vim htop
)
CONFIG_FILES=(user-dirs.dirs user-dirs.locale mimeapps.list)
HOME_FILES=(.zshrc .bashrc .bash_profile .zprofile .gtkrc-2.0 .Xresources .yarnrc)

rm -rf "$CFG" "$HOMEF"
mkdir -p "$CFG" "$HOMEF"

cd "$HOME/.config"
for d in "${CONFIG_DIRS[@]}"; do
    [ -d "$d" ] || { echo "skip (missing): $d"; continue; }
    rsync -aL --exclude='.git' --exclude='*.bak' --exclude='htop_history' \
        --exclude='__pycache__' --exclude='*.pyc' "$d" "$CFG/"
done
for f in "${CONFIG_FILES[@]}"; do
    [ -f "$f" ] && cp -aL "$f" "$CFG/"
done

cd "$HOME"
for f in "${HOME_FILES[@]}"; do
    [ -f "$f" ] && cp -aL "$f" "$HOMEF/"
done

# login screen colour override
if [ -f "$HOME/.local/share/sddm-themes/sugar-candy-theme.conf.user" ]; then
    cp -a "$HOME/.local/share/sddm-themes/sugar-candy-theme.conf.user" \
        "$REPO/roles/sddm/files/sugar-candy-theme.conf.user"
fi

echo
echo ":: snapshot refreshed"
du -sh "$CFG" "$HOMEF"
echo ":: review with  git -C $REPO status"
