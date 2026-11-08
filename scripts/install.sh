#!/usr/bin/env bash
#
# SimpleNAS guided installer.
#
# Run from the official NixOS Minimal live environment, after cloning this repo:
#   git clone https://github.com/derikatwork/SimpleNas
#   sudo ./SimpleNas/scripts/install.sh
#
# It installs NixOS onto ONE boot disk you choose and leaves every other disk
# untouched. It REFUSES to write to any disk that holds a ZFS pool, so the
# existing "divine-storm" data disks are protected. See MIGRATION.md for the
# equivalent manual steps and the background.

set -euo pipefail

POOL="divine-storm"
FLAKE_ATTR="simplenas"

# --- Locate the repo (this script lives in <repo>/scripts/) ------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ ! -f "$REPO_DIR/flake.nix" ] || [ ! -f "$REPO_DIR/hosts/$FLAKE_ATTR/configuration.nix" ]; then
  echo "ERROR: can't find the SimpleNAS repo (expected flake.nix at $REPO_DIR)." >&2
  exit 1
fi

# --- Preconditions -----------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root:  sudo $0" >&2
  exit 1
fi

missing=""
for t in sgdisk mkfs.ext4 partprobe blkid lsblk nixos-generate-config nixos-install nixos-enter; do
  command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
done
if [ -n "$missing" ]; then
  echo "ERROR: missing tools:$missing" >&2
  echo "Run this inside the NixOS Minimal installer, or pull them in with:" >&2
  echo "  nix-shell -p gptfdisk e2fsprogs util-linux nixos-install-tools" >&2
  exit 1
fi

# nixos-install needs flakes enabled in the live environment.
export NIX_CONFIG="experimental-features = nix-command flakes"

echo "==================================================================="
echo " SimpleNAS guided installer"
echo "==================================================================="
echo
echo "Installs NixOS onto ONE boot disk; every other disk is left untouched."
echo "The '$POOL' ZFS pool is imported automatically on first boot — its disks"
echo "are NOT written here. Make sure you exported it on the old system first:"
echo "    zpool export $POOL     (or shut TrueNAS down cleanly)"
echo

echo "-------------------------------------------------------------------"
echo "Disks on this machine:"
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,TYPE
echo
echo "Stable device ids (use one of these for the boot disk):"
ls -l /dev/disk/by-id/
echo
echo "ZFS pool members (DO NOT pick these — your data lives here):"
if lsblk -no NAME,FSTYPE | grep -q zfs_member; then
  lsblk -o NAME,SIZE,MODEL,FSTYPE | grep -E 'zfs_member|NAME' || true
else
  echo "  (none currently labelled)"
fi
echo "-------------------------------------------------------------------"
echo

read -rp "Full /dev/disk/by-id path of the BOOT disk to ERASE + install onto: " BOOTDISK

case "$BOOTDISK" in
  /dev/disk/by-id/*) : ;;
  *) echo "ERROR: use a /dev/disk/by-id/... path (stable across reboots)." >&2; exit 1 ;;
esac
if [ ! -b "$BOOTDISK" ]; then
  echo "ERROR: '$BOOTDISK' is not a block device." >&2
  exit 1
fi

REAL="$(readlink -f "$BOOTDISK")"

# Refuse a disk (or any of its partitions) that is a ZFS pool member.
if blkid -o value -s TYPE "$BOOTDISK" "$REAL" "${REAL}"* 2>/dev/null | grep -q '^zfs_member$'; then
  echo "ERROR: $BOOTDISK holds a ZFS pool — refusing to erase it." >&2
  exit 1
fi
# Refuse a disk with a mounted partition (e.g. the live USB itself).
if lsblk -no MOUNTPOINT "$REAL" | grep -q .; then
  echo "ERROR: $BOOTDISK has a mounted partition — pick the target's internal boot disk, not the USB." >&2
  exit 1
fi

echo
echo "About to ERASE: $BOOTDISK  ->  $REAL"
lsblk -o NAME,SIZE,MODEL,SERIAL "$REAL"
echo
read -rp "Type ERASE (all caps) to confirm this is the correct disk: " CONFIRM
[ "$CONFIRM" = "ERASE" ] || { echo "Aborted."; exit 1; }

# --- Partition (BIOS: GPT with a 1 MiB BIOS-boot partition + ext4 root) ------
echo ">> Partitioning $BOOTDISK ..."
sgdisk --zap-all "$BOOTDISK"
sgdisk -n1:0:+1M -t1:ef02 -c1:BIOSBOOT "$BOOTDISK"   # BIOS boot partition for GRUB
sgdisk -n2:0:0   -t2:8300 -c2:nixos    "$BOOTDISK"   # root
partprobe "$BOOTDISK" || true
sleep 2

ROOTPART="${BOOTDISK}-part2"
echo ">> Formatting root ($ROOTPART) as ext4 ..."
mkfs.ext4 -F -L nixos "$ROOTPART"
sleep 1
mount /dev/disk/by-label/nixos /mnt

# --- Hardware config (pool is NOT imported, so no ZFS entries get written) ----
echo ">> Generating hardware configuration ..."
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/simplenas-hw.nix

# --- Lay down this repo's config, keeping the generated hardware file ---------
echo ">> Installing the SimpleNAS config to /mnt/etc/nixos ..."
rm -rf /mnt/etc/nixos
mkdir -p /mnt/etc/nixos
# Copy the repo contents (including dotfiles), excluding the git metadata.
cp -a "$REPO_DIR"/. /mnt/etc/nixos/
rm -rf /mnt/etc/nixos/.git
chmod -R u+w /mnt/etc/nixos
cp /tmp/simplenas-hw.nix /mnt/etc/nixos/hosts/$FLAKE_ATTR/hardware-configuration.nix

# --- Wire the GRUB boot device to the chosen disk ----------------------------
echo ">> Setting the GRUB boot device to $BOOTDISK ..."
sed -i "s|/dev/disk/by-id/REPLACE_WITH_BOOT_DISK|$BOOTDISK|" \
  /mnt/etc/nixos/modules/boot.nix

# --- Network interface names (can't be known ahead of time) ------------------
echo
echo "Network is static on eno1/eno2 by default. If your NIC names differ, the"
echo "box may come up without LAN networking (you can also fix it after boot)."
echo "Detected interfaces:"
ip -o link show 2>/dev/null | awk -F': ' '{print "  " $2}' | grep -v '^  lo$' || true
read -rp "Open modules/network.nix to edit NIC names now? [y/N] " EDITNET
case "${EDITNET:-N}" in
  y|Y) "${EDITOR:-nano}" /mnt/etc/nixos/modules/network.nix ;;
  *)   : ;;
esac

# --- Install -----------------------------------------------------------------
echo ">> Building and installing NixOS (this takes a while) ..."
echo "   (nixos-install will prompt for a ROOT password — keep it for console"
echo "    rescue; remote root login is disabled in the config.)"
nixos-install --flake "/mnt/etc/nixos#$FLAKE_ATTR"

# --- Set the primary user's password (none is shipped) -----------------------
echo
echo ">> Set a password for the 'nas' user (needed for sudo):"
nixos-enter --root /mnt -c 'passwd nas' || \
  echo "   (Set it after reboot with:  passwd nas )"

cat <<EOF

===================================================================
 Install complete.
 Remove the USB and reboot, then verify the pool imported:
   zpool status $POOL
   zfs list -o name,mountpoint
 If it didn't auto-import (pool wasn't exported):  zpool import -f $POOL
 Bring up remote access:  sudo tailscale up --ssh
===================================================================
EOF
