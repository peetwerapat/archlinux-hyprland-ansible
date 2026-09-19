# Arch + Hyprland workstation — machine reproduction with Ansible

This playbook rebuilds **this** workstation on a fresh Arch Linux install:
packages (pacman + AUR), enabled services, user groups, default shell, the
dotfiles and the login screen. Snapshot refreshed on 2026-09-19.

## What it does

| Role       | Action |
|------------|--------|
| `packages` | Installs all official-repo packages (`pacman`). |
| `aur`      | Bootstraps the `yay` helper, then installs AUR packages. |
| `services` | Enables system + user systemd services (bluetooth, docker, NetworkManager, sddm, tailscaled, pipewire, …). |
| `user`     | Adds you to `wheel` + `docker`, sets `zsh` as the login shell. |
| `matugen`  | `cargo install matugen --version 2.4.1` — the palette generator, pinned (see Notes). |
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
  layout indicator, Magic Trackpad battery. `launch.sh` restarts waybar if it
  crashes (its pulseaudio module segfaults when dock audio hotplugs).
- **rofi** — launcher, clipboard, screenshot, keybinding cheat sheet, plus the
  two waybar dropdown panels, all sharing one theme.
- **kitty** — custom tab bar (`kitty/tab_bar.py`): the active tab is a rounded
  pill in the matugen accent, tabs are named after the project (git root), and
  ssh tabs follow the remote path. Background is solid `#000000` so the padding
  around nvim is not a gray frame.
- **hyprlock / wlogout / swaync / nwg-dock** — same palette and radius scale.
- UI font: **Adwaita Sans**; terminal font: JetBrainsMono Nerd Font.

Wallpaper changes go through `waypaper`, whose `post_command` runs
`~/.config/hypr/scripts/wallpaper.sh` — that sets the wallpaper, refreshes the
blurred copy used by hyprlock/wlogout, re-runs matugen and reloads waybar.

### Monitors — Dell D6000 dock (DisplayLink)

The LG hangs off the laptop HDMI port, the Samsung off the D6000
(DisplayLink/evdi). Because DisplayLink connector names change on every
replug (`DVI-I-1`, `DVI-I-2`, …) and Hyprland can keep a stale description
after a hotplug, `hypr/scripts/monitor-mode.sh` matches monitors by the EDID
the kernel exposes in `/sys/class/drm/*/edid` instead. Five layouts, bound to
`SUPER+F1..F5`:

| Key | Mode | Layout |
|-----|------|--------|
| `SUPER+F1` | A | Samsung left (vertical) · **LG 2560x1440 main** · laptop right |
| `SUPER+F2` | B | whatever is on laptop HDMI on top · **laptop main** below |
| `SUPER+F3` | C | Samsung on top · laptop main · LG off |
| `SUPER+F4` | D | laptop main · Samsung right · LG off |
| `SUPER+F5` | E | laptop panel only, everything else forced off |

What this setup needs, and why:

- `displaylink` + `evdi-dkms` (AUR), `dkms` and `linux-headers` — and
  `displaylink.service` enabled.
- `AQ_NO_ATOMIC=1` and `AQ_MGPU_NO_EXPLICIT=1` are exported from
  **`~/.zprofile`**, not from `env =` in `hyprland.conf` — aquamarine reads
  them before the config is parsed. `AQ_NO_ATOMIC` costs a ~30 s freeze on
  every dock hotplug; comment it out if the LG moves back to laptop HDMI.
- `cursor:no_hardware_cursors = 1` — evdi flickers with hardware cursors.
- blur is down to 2 passes and `inactive_opacity` back to `1.0`: 3 passes are
  too heavy for the Intel UHD across three screens.

### Apple Magic Trackpad

`hypr/conf/trackpad.conf` (sourced from `hyprland.conf`) holds the touchpad
defaults, the per-device Magic Trackpad block and the macOS-style gestures:
3 fingers horizontal = workspaces, 3 up = window switcher, 3 down =
notification centre, 4-finger pinch in = launcher, pinch out = empty
workspace, 4 horizontal = drag window, 4 up = fullscreen. The built-in
synaptics touchpad moved here too — its old `device = name:key,value` lines
in `keyboard.conf` were never valid syntax, and its sensitivity of `3` was
outside the allowed `-1.0 .. 1.0` range.

Battery comes from `magic-trackpad-battery-git` (AUR): a user daemon writes
`$XDG_RUNTIME_DIR/magic-trackpad-battery.json`, and
`waybar/scripts/trackpad-battery.py` renders it — hiding the module whenever
the trackpad is not on Bluetooth.

### Neovim

`nvim/lua/peetwerapat/core/ai.lua` replaced the old `ollama.lua`: one chat
window over several providers — local Ollama (`qwen2.5-coder` 7b/14b),
`claude` and `codex` CLIs, and `qwen3-coder-next:cloud`. Model and limits are
overridable with `OLLAMA_HOST`, `OLLAMA_MODEL_ASK`, `OLLAMA_MODEL_CODE`,
`AI_MAX_FILES`, `AI_MAX_FILE_CHARS`, `AI_MAX_TOTAL_CHARS`.

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
ansible-playbook site.yml --ask-become-pass --tags dotfiles   # includes matugen
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
- **matugen is pinned to 2.4.1 and installed with `cargo`**, not pacman. The
  repo package is 4.x and does not read the 2.x
  `~/.config/matugen/config.toml`; `hypr/scripts/wallpaper.sh` calls
  `~/.cargo/bin/matugen` by absolute path. `cargo install` compiles from
  source — the first run of the `matugen` tag takes a few minutes.
- The login theme needs the AUR package `sddm-sugar-candy-git`. The `sddm`
  role never edits the packaged `theme.conf` — it drops a `theme.conf.user`
  next to it, so `sudo rm .../theme.conf.user` restores the stock look.
  (On the source machine the theme now sits in
  `/usr/share/sddm/themes/sddm-sugar-candy` unowned by any package — the AUR
  package is kept in the list because that is the reproducible way to get it.)
- The first dotfiles run backs up any existing `~/.config` to
  `~/.config.bak-ansible` before writing.
- App state that is *not* settings (browser profiles, Electron caches,
  JetBrains, etc.) was intentionally **not** captured — only configuration.
- `trackpoint-fix.service` is machine-specific and deliberately left out of
  `system_services`; `snapd`, `snapd.apparmor` and `teamviewerd` are enabled
  on the source box but stay in the commented-out optional list.
- `git` config lives at `.config/git/config` and tmux at
  `.config/tmux/tmux.conf` (both moved out of `$HOME`). The git config
  contains your real name and email — keep this repo **private**.
- Only one wallpaper (`DesktopBG.jpeg`) ships with the playbook; copy the rest
  of `~/wallpaper` over by hand if you want them.

## Re-snapshotting the dotfiles later

```bash
bash capture.sh      # refreshes roles/dotfiles/files from this machine
```
