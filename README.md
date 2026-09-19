# SimpleNAS

A minimal, reproducible **NixOS NAS** built as a flake. It gives you a ZFS
storage box you administer over Tailscale, with a lightweight labwc (Wayland)
desktop for when you plug in a monitor.

## What's in the build

| Area          | Choice                                                                 |
|---------------|-----------------------------------------------------------------------|
| Config format | **Flakes** (`nixos-25.11`, pinned via `flake.lock`)                     |
| Bootloader    | **UEFI + systemd-boot** (legacy-BIOS/GRUB alternative documented)      |
| Storage       | **ZFS**, **RAIDZ1** data pool (`tank`), weekly scrub, auto-snapshots   |
| Encryption    | Off by default (unattended reboot); native ZFS encryption documented  |
| Networking    | NetworkManager + **Tailscale** with **Tailscale SSH**                  |
| File sharing  | SMB + NFS supported but **commented out**; access via Tailscale for now |
| Desktop       | Wayland + **labwc** compositor, **auto-login** via greetd               |
| Shell / editor| **Bash** (default) + **Nano**                                          |
| Services      | Minimal — NAS + Tailscale + desktop only                              |

## Layout

```
flake.nix                              # inputs + nixosConfigurations.simplenas
hosts/simplenas/
  configuration.nix                    # identity, locale, imports
  hardware-configuration.nix           # ⚠ PLACEHOLDER — regenerate on target
modules/
  base.nix                             # nix settings, bash, nano, CLI tools, smartd
  boot.nix                             # systemd-boot (GRUB alt commented)
  zfs.nix                              # ZFS enable + scrub/snapshot + pool recipe
  network.nix                          # NetworkManager, Tailscale SSH, firewall, sshd
  desktop.nix                          # labwc (Wayland) + greetd auto-login
  users.nix                            # primary user account
  nas.nix                              # Samba + NFS (both commented out)
```

## Before you deploy — things to change

- **`hosts/simplenas/hardware-configuration.nix`** is a stub. Replace it with the
  file `nixos-generate-config` produces on the real machine (see install steps).
- **Timezone** in `hosts/simplenas/configuration.nix` (`time.timeZone`).
- **Username / password / SSH keys** in `modules/users.nix` (default user is
  `nas` with password `changeme` — change it!). If you rename the user, also
  update the `username` let-binding in `modules/desktop.nix` (greetd auto-login).
- **Disk ids** for the ZFS pool — see the recipe in `modules/zfs.nix`.
- `networking.hostId` is pre-generated (`5af23065`); keep it unique per machine.

## Install (high level)

1. Boot the NixOS installer, partition + format your **boot disk** (EFI system
   partition + a root filesystem, or ZFS-on-root if you prefer).
2. **Create the ZFS data pool** on your dedicated disks — full RAIDZ1 recipe is
   in `modules/zfs.nix`.
3. Generate hardware config:
   ```
   nixos-generate-config --root /mnt
   ```
   Clone this repo to `/mnt/etc/nixos` (or anywhere) and copy the generated
   `hardware-configuration.nix` over the placeholder here.
4. Make your edits (timezone, user, disks) as listed above.
5. Install from the flake:
   ```
   nixos-install --flake /mnt/etc/nixos#simplenas
   ```
6. Reboot, log in, set a real password (`passwd`), then bring up Tailscale:
   ```
   sudo tailscale up --ssh
   ```

## Day-2 operations

- **Rebuild after edits:** `sudo nixos-rebuild switch --flake .#simplenas`
- **Update packages:** `nix flake update` then rebuild.
- **Check pool health:** `zpool status`, `zpool list`
- **Snapshots:** listed with `zfs list -t snapshot` (auto-managed per `zfs.nix`).
- **Drive health:** `smartctl -a /dev/sdX` (smartd runs in the background).

## Turning on LAN file sharing later

Open `modules/nas.nix`, uncomment the **Samba** and/or **NFS** block, point the
share paths at your ZFS datasets (e.g. `/srv/data`), adjust allowed hosts, then
`nixos-rebuild switch`. For Samba, set the share user's password with
`sudo smbpasswd -a nas`.
