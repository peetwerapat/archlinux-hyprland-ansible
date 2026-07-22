# Arch + Hyprland (ML4W) — machine reproduction with Ansible

This playbook rebuilds **this** workstation on a fresh Arch Linux install:
packages (pacman + AUR), enabled services, user groups, default shell, and
your dotfiles. It was generated from the source machine on 2026-07-22.

## What it does

| Role       | Action |
|------------|--------|
| `packages` | Installs all official-repo packages (`pacman`). |
| `aur`      | Bootstraps the `yay` helper, then installs AUR packages. |
| `services` | Enables system + user systemd services (bluetooth, docker, NetworkManager, sddm, tailscaled, pipewire, …). |
| `user`     | Adds you to `wheel` + `docker`, sets `zsh` as the login shell. |
| `dotfiles` | Deploys a snapshot of `~/.config/*` and home dotfiles (hypr, waybar, nvim, kitty, rofi, zsh, …). |

The dotfiles snapshot lives in `roles/dotfiles/files/`. Symlinks were
dereferenced at capture time, so it is self-contained (no dependency on
`~/dotfiles`).

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
cd ansible
ansible-playbook site.yml --ask-become-pass      # asks once for your sudo password
```

Run just one part with tags:

```bash
ansible-playbook site.yml --ask-become-pass --tags packages
ansible-playbook site.yml --ask-become-pass --tags dotfiles
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

- `roles/dotfiles/files/home/.gitconfig` contains your real name and email.
  Keep this repo **private** if you push it anywhere.
- The first dotfiles run backs up any existing `~/.config` to
  `~/.config.bak-ansible` before writing.
- App state that is *not* settings (browser profiles, Electron caches,
  JetBrains, etc.) was intentionally **not** captured — only configuration.
- Machine-specific units (e.g. a custom `trackpoint-fix.service`) were left
  out on purpose.

## Re-snapshotting the dotfiles later

If you change configs on the source machine and want to refresh the snapshot,
re-run the capture (see the loop in the project history) or simply
`rsync -aL --exclude .cache ~/.config/<dir> roles/dotfiles/files/config/`.
