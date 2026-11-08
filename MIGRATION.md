# Migrating from TrueNAS SCALE to SimpleNAS (NixOS)

This guide replaces a **TrueNAS SCALE** install with this NixOS configuration on
the **same hardware**, using the official **NixOS Minimal** ISO as the base. It
**imports your existing ZFS pool (`divine-storm`) as-is** — your data and
snapshots are preserved; only the **boot disk** is reinstalled.

> Read `README.md` first for what the config contains and the values you must set.

---

## 0. Before you start

**You need:**
- The **NixOS Minimal ISO** (x86_64) from <https://nixos.org/download> — match the
  release this repo tracks (`nixos-25.11`). Write it to a USB stick:
  ```
  sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
  ```
- Console access to the NAS (monitor + keyboard, or the board's IPMI/BMC KVM).
- A wired network connection (the installer downloads packages).
- 10 minutes to confirm **which physical disk is the boot disk** vs the four
  pool disks — getting this wrong is the only way to lose data.

**Golden rule:** the four `divine-storm` pool disks are **never partitioned or
formatted** in this process. You only touch the boot disk.

---

## 1. On the TrueNAS box: export the pool

So NixOS can import the pool without a forced host-ID override, stop sharing and
export it (or just shut down cleanly):

```
# In the TrueNAS shell, after stopping SMB/NFS/apps:
zpool export divine-storm
```

Then power off and boot the **NixOS Minimal** USB.

---

## 2. Install — the easy way (guided script)

From the NixOS Minimal live environment, clone this repo and run the installer:

```
nix-shell -p git --run 'git clone https://github.com/derikatwork/SimpleNas'
sudo ./SimpleNas/scripts/install.sh
```

`scripts/install.sh` walks you through the rest and is **pool-safe** — it lists
disks, flags ZFS members, makes you type the boot disk's `by-id` path and confirm
with `ERASE`, and **refuses to write to any disk that holds a pool**. It then
partitions only that disk (BIOS layout), lays down this config, auto-fills the
GRUB device, offers to fix the NIC names, runs `nixos-install`, and sets the
passwords. When it finishes, **skip to "Reboot and verify" below**.

Prefer to do each step yourself? Follow the manual steps below instead.

---

## Manual install (alternative to the script)

### Identify the disks (by stable id)

`sdX` names are not stable — always work by `/dev/disk/by-id`.

```
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE
ls -l /dev/disk/by-id/
```

- The **pool disks** show `zfs_member` partitions (and are the four large,
  matching data drives). **Leave them alone.**
- The **boot disk** is the small SSD TrueNAS booted from. Note its `by-id` path,
  e.g. `/dev/disk/by-id/ata-INTEL_SSDSC2BB080G4_BTWL...`.

Set it in a variable for the commands below (double-check it first!):

```
DISK=/dev/disk/by-id/ata-YOUR_BOOT_DISK   # <-- the boot disk, NOT a pool disk
```

---

### Partition & format the boot disk (BIOS layout)

This machine boots in **legacy BIOS** mode, so we use a GPT with a 1 MiB
BIOS-boot partition for GRUB plus an ext4 root. **This erases `$DISK`.**

```
sudo -i
export NIX_CONFIG="experimental-features = nix-command flakes"

sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1M -t1:ef02 -c1:BIOSBOOT "$DISK"   # BIOS boot partition (for GRUB)
sgdisk -n2:0:0   -t2:8300 -c2:nixos    "$DISK"   # root
partprobe "$DISK"; sleep 2

mkfs.ext4 -L nixos "${DISK}-part2"
mount /dev/disk/by-label/nixos /mnt
```

> **UEFI instead?** If you switch the firmware to UEFI, make an ESP instead of
> the BIOS-boot partition (`-t1:ef00`, `mkfs.fat -F32`, mount at `/mnt/boot`) and
> flip `modules/boot.nix` to the systemd-boot block. The rest is identical.

---

### Generate the hardware config

Do this **before** importing the pool, so the scan only sees the boot disk and
doesn't write `divine-storm` filesystem entries:

```
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix
```

---

### Put this configuration in place

Replace the generated `/mnt/etc/nixos` with this repo, then drop the real
hardware config into it:

```
rm -rf /mnt/etc/nixos
git clone https://github.com/derikatwork/SimpleNas /mnt/etc/nixos
cp /tmp/hardware-configuration.nix \
   /mnt/etc/nixos/hosts/simplenas/hardware-configuration.nix
```

> If `git` isn't present: `nix-shell -p git`. If the repo is **private**, clone it
> with a token or copy the files onto the USB and `cp -r` them to
> `/mnt/etc/nixos` instead — then restore the hardware file as above.

---

### Edit the placeholders

```
cd /mnt/etc/nixos
nano modules/boot.nix       # set boot.loader.grub.device = "$DISK" (the by-id path)
nano modules/network.nix    # set accessNic / mgmtNic to real names; confirm gateway/DNS
```

- **`modules/boot.nix`** — `boot.loader.grub.device` → your boot disk's `by-id`
  path (the `$DISK` value above).
- **`modules/network.nix`** — set `accessNic` (→ 192.168.0.222) and `mgmtNic`
  (→ 192.168.0.228) to the real interface names. Find them with `ip -o link`
  (e.g. `eno1`, `eno2`). Confirm the gateway/DNS (assumed `192.168.0.1`).
  Unsure of the names? Switch to DHCP for now (see the comment in that file) and
  fix it after first boot.

Already set for you: hostname `simplenas`, timezone `America/Los_Angeles`,
Intel Xeon microcode, ZFS pool `divine-storm`, `networking.hostId`.

---

### Pin nixpkgs (optional), validate, and install

```
# Optional but recommended for a reproducible build:
nix flake lock          # writes flake.lock pinning the exact nixpkgs revision

nix flake check         # sanity-check the config now that hardware-configuration.nix is real
nixos-install --flake /mnt/etc/nixos#simplenas
```

`nixos-install` prompts for a **root** password at the end (keep it for emergency
console rescue; remote root login is disabled in the config). Then set the `nas`
account's password (it ships with none, so `sudo` won't work until you do):

```
nixos-enter --root /mnt -c 'passwd nas'
```

---

## Reboot and verify

Remove the USB and reboot. Then:

```
zpool status divine-storm            # pool imported and ONLINE?
zfs list -o name,mountpoint          # datasets mounted (TrueNAS puts them under /mnt/divine-storm)
```

If the pool did **not** auto-import (it wasn't cleanly exported in step 1):

```
sudo zpool import -f divine-storm     # one-time; subsequent boots are clean
sudo reboot
```

Bring up remote access over Tailscale:

```
sudo tailscale up --ssh               # authenticate once; then SSH over the tailnet
```

---

## Post-migration

- **Re-enable your shares.** SMB/NFS are present but commented out in
  `modules/nas.nix`. Reuse your old TrueNAS **share names** and point them at the
  dataset paths under `/mnt/divine-storm/...`, then `nixos-rebuild switch`. For
  Samba set passwords with `sudo smbpasswd -a nas`.
- **Snapshots.** Your imported TrueNAS snapshots are intact. NixOS auto-snapshots
  only datasets tagged `com.sun:auto-snapshot=true`
  (`zfs set com.sun:auto-snapshot=true divine-storm/<dataset>`).
- **Keep editing at `/etc/nixos`** — that's what the weekly auto-upgrade rebuilds
  from. After edits: `sudo nixos-rebuild switch --flake /etc/nixos#simplenas`.
  If you *add* a new `.nix` file in a git checkout, `git add` it or Nix ignores it.

See `README.md` → *Day-2 operations*, *Recovery*, and *Security notes* for the rest.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| **Won't boot** after install (old BIOS + GPT) | A few 2010-era BIOSes dislike GPT in legacy mode. Reinstall with an MBR/`msdos` layout on the boot disk (one ext4 root, no BIOS-boot partition) and keep GRUB pointed at the whole disk. |
| **No network** on first boot | Wrong NIC name. Console in, `ip -o link`, fix `accessNic`/`mgmtNic` in `modules/network.nix`, `nixos-rebuild switch`. Temporary net: `sudo dhcpcd <iface>`. |
| **Pool not mounted** | `sudo zpool import -f divine-storm` then reboot. Pool data is never touched by the reinstall. |
| **Desktop (labwc) won't start** | The NAS still works headless — use SSH/Tailscale/console. labwc already runs with `WLR_RENDERER=pixman` for BMC GPUs; to drop the desktop entirely, remove `../../modules/desktop.nix` from `hosts/simplenas/configuration.nix` and rebuild. |
| **A weekly upgrade broke something** | `sudo nixos-rebuild switch --rollback`, or pick the previous generation in the GRUB menu. |
