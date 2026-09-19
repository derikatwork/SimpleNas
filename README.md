# SimpleNAS

A minimal, reproducible **NixOS NAS** built as a flake — configured as a
**drop-in replacement for an existing TrueNAS SCALE box**. It imports the
existing ZFS pool as-is (no data movement), reproduces the network identity, and
adds a lightweight labwc (Wayland) desktop plus Tailscale for remote admin.

## What's in the build

| Area          | Choice                                                                    |
|---------------|---------------------------------------------------------------------------|
| Config format | **Flakes** (`nixos-25.11`, pinned via `flake.lock`)                        |
| Bootloader    | **Legacy BIOS + GRUB** (matches current firmware; UEFI alt documented)    |
| Storage       | **Imports existing ZFS pool `divine-storm`** (unencrypted); scrub + snaps |
| Networking    | **Static**, dual-NIC (`192.168.0.222` + `.228`/24) + **Tailscale SSH**    |
| File sharing  | SMB + NFS supported but **commented out**; access via Tailscale for now    |
| Desktop       | Wayland + **labwc** compositor, **auto-login** via greetd                  |
| Shell / editor| **Bash** (default) + **Nano**                                             |
| Services      | Minimal — NAS + Tailscale + desktop only                                  |

> Migrating **from TrueNAS SCALE**: the pool is imported, not recreated. Your
> data and existing snapshots are preserved. TrueNAS's *scheduled* snapshot and
> scrub tasks do not carry over — NixOS provides its own (see `modules/zfs.nix`).

## Layout

```
flake.nix                              # inputs + nixosConfigurations.simplenas
hosts/simplenas/
  configuration.nix                    # hostname, hostId, CPU microcode, locale
  hardware-configuration.nix           # ⚠ PLACEHOLDER — regenerate on target
modules/
  base.nix                             # nix settings, bash, nano, CLI tools, smartd
  boot.nix                             # BIOS GRUB (UEFI/systemd-boot alt commented)
  zfs.nix                              # imports pool "divine-storm" + scrub/snapshot
  network.nix                          # static dual-NIC, Tailscale SSH, firewall, sshd
  desktop.nix                          # labwc (Wayland) + greetd auto-login
  users.nix                            # primary user account
  nas.nix                              # Samba + NFS (both commented out)
```

## Before you deploy — things to set

- **`hosts/simplenas/hardware-configuration.nix`** is a stub. Replace it with the
  file `nixos-generate-config` produces on the real machine (see below).
- **GRUB boot disk** in `modules/boot.nix`: set `boot.loader.grub.device` to the
  boot SSD's **`/dev/disk/by-id/...`** path (was `sdb` on TrueNAS, but confirm —
  Linux may enumerate disks differently).
- **NIC names** in `modules/network.nix`: set `accessNic` (192.168.0.222) and
  `mgmtNic` (192.168.0.228) to your real interface names (`ip -o link`), confirm
  which physical port is which, and confirm the **gateway/DNS** (assumed
  `192.168.0.1`).
- **Username / password / SSH keys** in `modules/users.nix` (default user is
  `nas` with password `changeme` — change it!). If you rename the user, also
  update the `username` let-binding in `modules/desktop.nix` (greetd auto-login).
- `networking.hostId` is pre-generated (`5af23065`); keep it unique per machine.

Already set for you: hostname `simplenas`, timezone `America/Los_Angeles`,
Intel Xeon microcode, pool name `divine-storm`.

## Migration / install (from TrueNAS SCALE)

1. **On the TrueNAS box:** stop SMB/NFS/apps, then cleanly export the pool so
   NixOS can import it without a forced host-ID override:
   ```
   zpool export divine-storm
   ```
   (or just shut TrueNAS down gracefully).
2. Boot the NixOS installer. **Identify disks by stable id** and note which is
   the boot disk vs the four pool disks — do NOT touch the pool disks:
   ```
   ls -l /dev/disk/by-id/
   lsblk -o NAME,SIZE,MODEL,SERIAL
   ```
3. Partition + format **only the boot disk** (BIOS: a small BIOS-boot/GRUB setup
   + a root filesystem — no EFI partition needed), and mount root at `/mnt`.
4. Generate hardware config, then drop this repo in and copy the result over the
   placeholder:
   ```
   nixos-generate-config --root /mnt
   ```
5. Make the edits under **Before you deploy** (GRUB `by-id` device, NIC names,
   user/password), then validate and install:
   ```
   nix flake check
   nixos-install --flake /mnt/etc/nixos#simplenas
   ```
6. Reboot. Verify the pool imported and mounted:
   ```
   zpool status divine-storm
   zfs list -o name,mountpoint
   ```
   If it wasn't cleanly exported, import once by hand then reboot:
   `zpool import -f divine-storm`.
7. Set a real password (`passwd`) and bring up Tailscale:
   ```
   sudo tailscale up --ssh
   ```

## Day-2 operations

- **Rebuild after edits:** `sudo nixos-rebuild switch --flake .#simplenas`
- **Update packages:** `nix flake update` then rebuild.
- **Check pool health:** `zpool status`, `zpool list`
- **Snapshots:** `zfs list -t snapshot`. To let NixOS auto-snapshot a dataset:
  `zfs set com.sun:auto-snapshot=true divine-storm/<dataset>`.
- **Drive health:** `smartctl -a /dev/disk/by-id/...` (smartd runs in background).

## Turning on LAN file sharing later

Open `modules/nas.nix`, uncomment the **Samba** and/or **NFS** block, point the
share paths at your datasets under `/mnt/divine-storm/...`, adjust allowed hosts,
then `nixos-rebuild switch`. For Samba, set the user's password with
`sudo smbpasswd -a nas`.
