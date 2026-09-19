{ config, pkgs, lib, modulesPath, ... }:

# A bootable NixOS live ISO that carries this whole repo and a guided installer
# for the SimpleNAS drop-in. This is a SEPARATE live system from the installed
# NAS — it does not import the pool or run the NAS services; it only installs
# them onto the target's boot disk.
#
# Build it on any machine with Nix:
#   nix build .#iso            # -> result/iso/simplenas-installer.iso
# Then write it to a USB stick (⚠ picks the USB device, not a data disk):
#   sudo dd if=result/iso/simplenas-installer.iso of=/dev/sdX bs=4M status=progress oflag=sync
#
# Boot the target from that USB, log in as the "nixos" user (auto-login), and run:
#   sudo install-simplenas

let
  # Guided installer. Heavy on confirmations and REFUSES to write to any disk
  # that holds a ZFS pool, so your divine-storm data disks are protected.
  install-simplenas = pkgs.writeShellApplication {
    name = "install-simplenas";
    runtimeInputs = with pkgs; [
      gptfdisk parted e2fsprogs util-linux gawk gnused coreutils
      nixos-install-tools
    ];
    text = ''
      set -euo pipefail

      echo "==================================================================="
      echo " SimpleNAS guided installer"
      echo "==================================================================="
      echo
      echo "This installs NixOS onto ONE boot disk and leaves every other disk"
      echo "untouched. Your ZFS pool 'divine-storm' is imported automatically on"
      echo "first boot of the installed system — its disks are NOT written here."
      echo
      echo "STEP 0: make sure you exported the pool on the old system first:"
      echo "        zpool export divine-storm   (or shut TrueNAS down cleanly)"
      echo

      echo "-------------------------------------------------------------------"
      echo "Disks seen on this machine:"
      lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,TYPE
      echo
      echo "Stable device ids (use one of these for the boot disk):"
      ls -l /dev/disk/by-id/
      echo
      echo "Disks/partitions that are ZFS pool members (DO NOT choose these):"
      if lsblk -no NAME,FSTYPE | grep -q zfs_member; then
        lsblk -o NAME,SIZE,MODEL,FSTYPE | grep -E 'zfs_member|NAME' || true
      else
        echo "  (none detected as imported/labelled right now)"
      fi
      echo "-------------------------------------------------------------------"
      echo

      read -rp "Full /dev/disk/by-id path of the BOOT disk to ERASE + install onto: " BOOTDISK
      if [ ! -b "$BOOTDISK" ]; then
        echo "ERROR: '$BOOTDISK' is not a block device." >&2; exit 1
      fi

      REAL="$(readlink -f "$BOOTDISK")"

      # Refuse if the chosen disk (or any of its partitions) is a ZFS member.
      if blkid -o value -s TYPE "$BOOTDISK" "$REAL" "''${REAL}"* 2>/dev/null | grep -q '^zfs_member$'; then
        echo "ERROR: $BOOTDISK holds a ZFS pool — refusing to erase it." >&2; exit 1
      fi
      # Refuse if anything on it is currently mounted (e.g. the live USB itself).
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

      echo ">> Partitioning $BOOTDISK (GPT: 1MiB BIOS-boot + ext4 root)…"
      sgdisk --zap-all "$BOOTDISK"
      sgdisk -n1:0:+1M   -t1:ef02 -c1:BIOSBOOT "$BOOTDISK"   # BIOS boot partition for GRUB
      sgdisk -n2:0:0     -t2:8300 -c2:nixos    "$BOOTDISK"   # root
      partprobe "$BOOTDISK" || true
      sleep 2

      ROOTPART="$BOOTDISK-part2"
      echo ">> Formatting root ($ROOTPART) as ext4…"
      mkfs.ext4 -F -L nixos "$ROOTPART"
      sleep 1
      mount /dev/disk/by-label/nixos /mnt

      echo ">> Generating hardware config for the boot disk…"
      nixos-generate-config --root /mnt          # pool is NOT imported, so no ZFS entries
      cp /mnt/etc/nixos/hardware-configuration.nix /tmp/hw.nix

      echo ">> Installing the SimpleNAS config to /mnt/etc/nixos…"
      rm -rf /mnt/etc/nixos
      cp -r /etc/simplenas /mnt/etc/nixos
      chmod -R u+w /mnt/etc/nixos
      cp /tmp/hw.nix /mnt/etc/nixos/hosts/simplenas/hardware-configuration.nix

      echo ">> Wiring the GRUB boot device to $BOOTDISK…"
      sed -i "s|/dev/disk/by-id/REPLACE_WITH_BOOT_DISK|$BOOTDISK|" \
        /mnt/etc/nixos/modules/boot.nix

      echo
      echo "NOTE: network is static on eno1/eno2 by default. If your NIC names"
      echo "differ, the box may come up without LAN networking. You can either:"
      echo "  - fix modules/network.nix now (nano /mnt/etc/nixos/modules/network.nix), or"
      echo "  - fix it after first boot from the console (see the README)."
      read -rp "Open network.nix in nano before installing? [y/N] " EDITNET
      case "''${EDITNET:-N}" in
        y|Y) nano /mnt/etc/nixos/modules/network.nix ;;
        *)   : ;;
      esac

      echo ">> Building and installing NixOS (this takes a while)…"
      nixos-install --no-root-passwd --flake /mnt/etc/nixos#simplenas

      echo
      echo "==================================================================="
      echo " Install complete."
      echo " Setting a password for the 'nas' user now (do not skip this):"
      nixos-enter --root /mnt -c 'passwd nas' || \
        echo " (Set it after reboot with: passwd nas)"
      echo
      echo " Remove the USB and reboot. After boot, verify the pool:"
      echo "   zpool status divine-storm"
      echo "   zfs list -o name,mountpoint"
      echo " If it didn't auto-import (pool wasn't exported):  zpool import -f divine-storm"
      echo " Then bring up Tailscale:  sudo tailscale up --ssh"
      echo "==================================================================="
    '';
  };
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # Name the image.
  isoImage.isoName = lib.mkForce "simplenas-installer.iso";
  isoImage.volumeID = lib.mkForce "SIMPLENAS_INSTALL";

  # ZFS in the live environment (to inspect / force-import the pool if needed).
  boot.supportedFilesystems.zfs = true;
  # ZFS requires a hostId; any value is fine for a throwaway live system.
  networking.hostId = "0badf00d";
  networking.hostName = "simplenas-installer";
  nixpkgs.config.allowUnfree = true;
  # If the ISO ever fails to build due to a ZFS/kernel mismatch, pin an older
  # kernel here, e.g.:  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;

  # Flakes available in the live env (needed for nixos-install --flake).
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bake this whole repo into the ISO so the config is present on the target.
  # (Package builds during `nixos-install` still fetch from the internet — the
  # live env uses DHCP, so plug in a network cable during install.)
  environment.etc."simplenas".source = ../.;

  # Tools + the guided installer on the live system.
  environment.systemPackages = with pkgs; [
    install-simplenas
    git nano vim
    gptfdisk parted
    pciutils usbutils smartmontools
  ];

  # Point the user at the installer on login.
  users.motd = ''

    ┌───────────────────────────────────────────────────────────────┐
    │  SimpleNAS installer live environment                          │
    │                                                               │
    │  Run the guided installer with:   sudo install-simplenas       │
    │                                                               │
    │  It installs onto ONE boot disk you choose and refuses to      │
    │  touch ZFS pool disks. Export 'divine-storm' on the old box    │
    │  first (zpool export divine-storm).                            │
    └───────────────────────────────────────────────────────────────┘
  '';
}
