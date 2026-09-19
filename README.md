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
| Apps          | **Flatpak** enabled with the **Flathub** remote pre-registered             |
| Shell / editor| **Bash** (default) + **Nano**                                             |
| Updates       | **Weekly auto-upgrade**, Fri 02:00, from pinned `nixos-25.11` backports    |
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
  flatpak.nix                          # Flatpak + Flathub remote (auto-registered)
  auto-upgrade.nix                     # weekly security auto-updates (Fri 02:00)
iso/
  configuration.nix                    # bootable live ISO + guided installer
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

## Option A: build a bootable installer ISO (easiest)

Instead of the manual steps below, you can build a live USB image that carries
this repo and a **guided installer**. Build it on any machine with Nix (it needs
internet and a few GB; it can't be built on the NAS itself before NixOS is on it):

```
nix build .#iso          # -> result/iso/simplenas-installer.iso
```

Write it to a USB stick (⚠ target the USB device, not a data disk):

```
sudo dd if=result/iso/simplenas-installer.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**Don't want to build it yourself?** GitHub Actions builds the ISO for you
(`.github/workflows/build-iso.yml`):
- Every push to `main` (or a manual **Run workflow**) uploads the ISO under the
  run's **Artifacts** → `simplenas-installer-iso`.
- Pushing a tag like `v1.0` publishes a **Release** with the ISO attached (a
  stable download link): `git tag v1.0 && git push origin v1.0`.

The live ISO boots into a **labwc (Wayland) desktop** and auto-opens a terminal;
run the installer from there (or via the right-click menu → *Run installer*).
If the GPU can't do Wayland, switch to a text console with **Ctrl+Alt+F2** and
run the same command. Boot the NAS from the USB and run:

```
sudo install-simplenas
```

The guided installer:
- lists disks by stable id and **flags ZFS-member disks**, then makes you type
  the boot disk's id and confirm with `ERASE` — it **refuses to write to any disk
  that holds a ZFS pool**, so `divine-storm` is protected;
- partitions **only** that boot disk (BIOS layout), installs the config, and
  **auto-fills the GRUB device** for you;
- offers to open `network.nix` so you can fix the NIC names before first boot;
- sets the `nas` password at the end.

Still do **`zpool export divine-storm`** on the old box first, and plug in a
network cable (the installer downloads packages). After reboot, verify with
`zpool status divine-storm`. Prefer to do it by hand? Use Option B.

## Option B: manual migration / install (from TrueNAS SCALE)

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
4. Generate hardware config, then clone this repo to `/mnt/etc/nixos` and copy
   the generated file over the placeholder:
   ```
   nixos-generate-config --root /mnt      # writes /mnt/etc/nixos/hardware-configuration.nix
   git clone <this repo> /mnt/etc/nixos   # keep the generated hardware-configuration.nix
   ```
   (Run `nixos-generate-config` while the pool is **not** imported so it doesn't
   add `divine-storm` entries — in a fresh installer it isn't imported.)
5. Make the edits under **Before you deploy** (GRUB `by-id` device, NIC names,
   user/password). Then validate and install (the installer needs flakes enabled):
   ```
   export NIX_CONFIG="experimental-features = nix-command flakes"
   cd /mnt/etc/nixos
   nix flake check                        # only passes once the real hardware file is in place
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

> Keep your edited config at **`/etc/nixos`** (that's what the weekly
> auto-upgrade rebuilds from). Edit files there and `nixos-rebuild switch`;
> if you *add* a new `.nix` file, `git add` it or Nix won't see it.

## Day-2 operations

- **Rebuild after edits:** `sudo nixos-rebuild switch --flake /etc/nixos#simplenas`
- **Roll back a bad change:** `sudo nixos-rebuild switch --rollback`, or pick an
  older "NixOS" entry in the GRUB boot menu. Every rebuild keeps the previous one.
- **Update packages now:** the weekly job does this automatically; to force it:
  `sudo systemctl start nixos-upgrade.service`
- **Check pool health:** `zpool status`, `zpool list`
- **Snapshots:** `zfs list -t snapshot`. To let NixOS auto-snapshot a dataset:
  `zfs set com.sun:auto-snapshot=true divine-storm/<dataset>`.
- **Drive health:** `smartctl -a /dev/disk/by-id/...` (smartd runs in background).

## If something goes wrong (recovery)

- **No network after first boot** (wrong NIC name in `modules/network.nix`):
  log in at the monitor/keyboard or a text console (Ctrl+Alt+F2), run
  `ip -o link` to get the real interface names, fix `accessNic`/`mgmtNic`, then
  `sudo nixos-rebuild switch --flake /etc/nixos#simplenas`. (Temporary net now:
  `sudo dhcpcd <iface>`.)
- **Pool didn't mount:** `sudo zpool import -f divine-storm` then reboot; check
  `zpool status`. Your data is on the pool disks and is not touched by a reinstall.
- **Desktop won't start** (old GPU): the NAS still works — use SSH/Tailscale or a
  text console. To go headless, remove `../../modules/desktop.nix` from the
  imports in `hosts/simplenas/configuration.nix` and rebuild.
- **A weekly upgrade broke something:** roll back (see above). The running system
  is never replaced until a new build succeeds, so a failed build is a no-op.
- **Boot disk filled up:** `sudo nix-collect-garbage -d` then rebuild.

## Installing apps (Flatpak)

Flatpak is enabled and the **Flathub** remote is registered automatically at
boot — no setup needed. From a terminal on the box:

```
flatpak install flathub org.videolan.VLC      # install (system-wide; uses polkit)
flatpak run org.videolan.VLC
flatpak update                                 # update all installed Flatpaks
flatpak list                                   # see what's installed
```

Browse apps at <https://flathub.org>. Prefer per-user installs? Add the remote
once with `flatpak --user remote-add --if-not-exists flathub
https://flathub.org/repo/flathub.flatpakrepo`, then `flatpak --user install …`.

## Turning on LAN file sharing later

Open `modules/nas.nix`, uncomment the **Samba** and/or **NFS** block, point the
share paths at your datasets under `/mnt/divine-storm/...`, adjust allowed hosts,
then `nixos-rebuild switch`. For Samba, set the user's password with
`sudo smbpasswd -a nas`.
