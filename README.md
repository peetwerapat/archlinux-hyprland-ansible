# Arch + Hyprland workstation — machine reproduction with Ansible

This playbook rebuilds **this** workstation on a fresh Arch Linux install:
packages (pacman + AUR), enabled services, user groups, default shell, the
dotfiles and the login screen. Snapshot refreshed on 2026-07-28.

## What it does

| Role       | Action |
|------------|--------|
| `packages` | Installs all official-repo packages (`pacman`). |
| `aur`      | Bootstraps the `yay` helper, then installs AUR packages. |
| `services` | Enables system + user systemd services (bluetooth, docker, NetworkManager, sddm, tailscaled, pipewire, …). |
| `user`     | Adds you to `wheel` + `docker`, sets `zsh` as the login shell. |
| `dotfiles` | Deploys `~/.config/*` and home dotfiles, seeds the wallpaper, links `~/.vim/vimrc`, generates the color palette. |
| `sddm`     | Restyles the Sugar Candy login theme with the desktop palette and selects it. |

The dotfiles snapshot lives in `roles/dotfiles/files/`. Symlinks were
dereferenced at capture time, so it is self-contained — the machine no longer
keeps a `~/dotfiles` tree.

## The desktop this builds

Hyprland with a blue-glass theme that follows the wallpaper:

- **matugen** generates one palette from the current wallpaper and writes it
  into waybar, rofi, swaync, kitty, GTK 3/4, qt6ct and hyprland color files.
  The accent is **pinned to blue** (`#4285f4`, harmonised with the wallpaper),
  so the highlight colour stays blue whatever image you set.
- **waybar** — three floating glass islands (workspaces · clock · system),
  hardware drawer on hover, volume and Wi-Fi dropdowns, uppercase keyboard
  layout indicator.
- **rofi** — launcher, clipboard, screenshot, keybinding cheat sheet, plus the
  two waybar dropdown panels, all sharing one theme.
- **hyprlock / wlogout / swaync / nwg-dock** — same palette and radius scale.
- UI font: **Adwaita Sans**; terminal font: JetBrainsMono Nerd Font.

Wallpaper changes go through `waypaper`, whose `post_command` runs
`~/.config/hypr/scripts/wallpaper.sh` — that sets the wallpaper, refreshes the
blurred copy used by hyprlock/wlogout, re-runs matugen and reloads waybar.

## Prerequisites on the NEW machine

1. A working Arch Linux base install with your user created and `sudo` access.
2. Ansible + git:
   ```bash
   sudo pacman -S --needed ansible git
   ```
3. (Only if you installed `ansible-core` instead of the full `ansible`)
   fetch the collections:
   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

## Run it

Copy this folder to the new machine, then:

```bash
ansible-playbook site.yml --ask-become-pass      # asks once for your sudo password
```

Run just one part with tags:

```bash
ansible-playbook site.yml --ask-become-pass --tags packages
ansible-playbook site.yml --ask-become-pass --tags dotfiles
ansible-playbook site.yml --ask-become-pass --tags sddm
```

Preview without changing anything:

```bash
ansible-playbook site.yml --ask-become-pass --check --diff
```

After it finishes: **log out and back in** (or reboot) so the new group
membership and default shell take effect, then let SDDM start Hyprland.

## Customizing before you run

Everything you'd tweak is in [`group_vars/all.yml`](group_vars/all.yml):

- **Different CPU/GPU vendor?** The list has Intel-specific packages
  (`intel-ucode`, `linux-firmware-intel`, `intel-media-driver`). Swap them
  for the AMD equivalents (`amd-ucode`, …) on AMD hardware.
- **Don't want an app?** Comment out its line under `pacman_packages` /
  `aur_packages`.
- **Extra services** (snapd, teamviewer, tlp) are listed but disabled by
  default — uncomment them under `system_services_optional`.

## Notes / caveats

- The desktop used to be built on the `ml4w-hyprland` meta package. That is
  gone; every tool it used to pull in as a dependency (kitty, hyprlock,
  hypridle, hyprpaper, xdg-desktop-portal-hyprland, qt5/qt6-wayland,
  libnotify, bluez-utils, vim, man-pages, zip) is now listed explicitly in
  `pacman_packages`. Do not remove them "because they look like extras".
- The login theme needs the AUR package `sddm-sugar-candy-git`. The `sddm`
  role never edits the packaged `theme.conf` — it drops a `theme.conf.user`
  next to it, so `sudo rm .../theme.conf.user` restores the stock look.
- The first dotfiles run backs up any existing `~/.config` to
  `~/.config.bak-ansible` before writing.
- App state that is *not* settings (browser profiles, Electron caches,
  JetBrains, etc.) was intentionally **not** captured — only configuration.
- `git` config lives at `.config/git/config` and tmux at
  `.config/tmux/tmux.conf` (both moved out of `$HOME`). The git config
  contains your real name and email — keep this repo **private**.
- Only one wallpaper (`DesktopBG.jpeg`) ships with the playbook; copy the rest
  of `~/wallpaper` over by hand if you want them.

## Re-snapshotting the dotfiles later

```bash
bash capture.sh      # refreshes roles/dotfiles/files from this machine
```
