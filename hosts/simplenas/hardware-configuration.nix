# ⚠️  PLACEHOLDER — DO NOT DEPLOY AS-IS ⚠️
#
# This file MUST be replaced with one generated on the actual target machine,
# because it describes that machine's real disks, filesystems, and kernel
# modules. Generate it during install with:
#
#   nixos-generate-config --root /mnt
#
# which writes /mnt/etc/nixos/hardware-configuration.nix. Copy that file over
# this one (keep the filename/location), then build.
#
# The stub below only exists so `nix flake check` can evaluate the config
# before you have real hardware. It intentionally defines no filesystems.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ── Filled in by nixos-generate-config on the target ──────────────────────
  # Example of what the generator produces (yours will differ):
  #
  # boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" ];
  # boot.kernelModules = [ "kvm-intel" ];
  #
  # This machine boots in LEGACY BIOS mode, so there is normally NO EFI /boot
  # vfat partition — just a root filesystem on the boot disk (sdb on TrueNAS,
  # but confirm by-id). The "divine-storm" ZFS pool is imported by modules/zfs.nix
  # and must NOT be listed here.
  #
  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";  # boot-disk root (e.g. ext4)
  #   fsType = "ext4";
  # };
  #
  # swapDevices = [
  #   # { device = "/dev/disk/by-uuid/XXXX..."; }   # optional swap partition
  # ];

  boot.initrd.availableKernelModules = [ ];
  boot.kernelModules = [ ];
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
