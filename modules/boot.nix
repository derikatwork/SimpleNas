{ config, pkgs, lib, ... }:

# Bootloader: UEFI + systemd-boot (the modern default). If your machine is
# legacy-BIOS only, comment this block out and configure GRUB instead — see the
# note at the bottom.

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep a bounded number of boot entries so /boot doesn't fill up.
  boot.loader.systemd-boot.configurationLimit = 10;

  # ── Legacy BIOS alternative (uncomment, and disable systemd-boot above) ─────
  # boot.loader.systemd-boot.enable = false;
  # boot.loader.efi.canTouchEfiVariables = false;
  # boot.loader.grub = {
  #   enable = true;
  #   # For ZFS-on-root with BIOS, point this at the whole disk(s), e.g.:
  #   devices = [ "/dev/disk/by-id/CHANGE-ME" ];
  #   efiSupport = false;
  # };
}
