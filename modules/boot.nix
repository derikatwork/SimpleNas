{ config, pkgs, lib, ... }:

# Bootloader. The current NAS boots in LEGACY BIOS mode, so this uses GRUB
# installed to the boot disk's MBR. (UEFI + systemd-boot alternative is at the
# bottom if you ever switch the firmware to UEFI.)

{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;

  boot.loader.grub = {
    enable = true;
    # BIOS GRUB must be installed to the whole BOOT disk (not a partition).
    # ⚠ Use a STABLE /dev/disk/by-id path, not /dev/sdX — Linux may enumerate
    # the disks differently than TrueNAS did (your boot disk was "sdb" there).
    # Find it with:  ls -l /dev/disk/by-id/   (match the boot SSD's model/serial)
    # then replace the placeholder below, e.g.
    #   device = "/dev/disk/by-id/ata-INTEL_SSDSC2BB080G4_BTWL1234567890";
    device = "/dev/disk/by-id/REPLACE_WITH_BOOT_DISK";

    # This is a BIOS (non-EFI) install.
    efiSupport = false;
  };

  # Keep a bounded number of boot generations so /boot doesn't fill up.
  boot.loader.grub.configurationLimit = 10;

  # ── UEFI alternative (only if you switch the firmware to UEFI) ───────────────
  # boot.loader.grub.enable = false;
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.systemd-boot.configurationLimit = 10;
}
