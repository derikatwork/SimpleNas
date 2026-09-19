{ config, pkgs, lib, ... }:

# ZFS support + maintenance. This module enables ZFS and sets up automatic
# scrubbing, snapshots, and TRIM. It does NOT create your pool — you create the
# pool by hand once during install (see the recipe at the bottom), and NixOS
# imports it on every boot.

{
  boot.supportedFilesystems.zfs = true;

  # Don't force-import pools that weren't cleanly exported (safer default; avoids
  # importing a pool that another machine might still own).
  boot.zfs.forceImportRoot = false;

  # Import the data pool at boot even though it isn't listed in
  # hardware-configuration.nix's fileSystems (ZFS manages its own mountpoints).
  # Rename "tank" if you named your pool something else.
  boot.zfs.extraPools = [ "tank" ];

  # Weekly scrub to catch and repair silent corruption. RAIDZ1 can self-heal
  # from one bad drive as long as scrubs run regularly.
  services.zfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  # Periodic TRIM for SSDs (no-op / harmless on spinning disks).
  services.zfs.trim.enable = true;

  # Automatic snapshots. Datasets opt in with the `com.sun:auto-snapshot`
  # property (see recipe). Adjust retention to taste.
  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 4;   # every 15 min, keep 4
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 3;
  };

  # ── One-time pool creation (RAIDZ1) ─────────────────────────────────────────
  # Run this ONCE during install, from the installer shell, BEFORE the first
  # `nixos-install`. Do it after partitioning your boot disk but you can create
  # the data pool on whole, dedicated disks.
  #
  # 1. Identify your disks by stable id (never /dev/sdX — those names shuffle):
  #      ls -l /dev/disk/by-id/
  #
  # 2. Create a RAIDZ1 pool named "tank" across 3+ disks. Example with 3 disks:
  #
  #      zpool create -f \
  #        -o ashift=12 \
  #        -O compression=zstd \
  #        -O atime=off \
  #        -O xattr=sa -O acltype=posixacl \
  #        -O mountpoint=none \
  #        tank raidz1 \
  #          /dev/disk/by-id/DISK-1 \
  #          /dev/disk/by-id/DISK-2 \
  #          /dev/disk/by-id/DISK-3
  #
  # 3. Create datasets for your shares and enable auto-snapshots on them:
  #
  #      zfs create -o mountpoint=/srv/data -o "com.sun:auto-snapshot=true" tank/data
  #      zfs create -o mountpoint=/srv/media -o "com.sun:auto-snapshot=true" tank/media
  #
  #    After this, `boot.zfs.extraPools = [ "tank" ]` above re-imports it on boot.
  #
  # ── Native encryption (optional) ────────────────────────────────────────────
  # This build leaves the pool UNENCRYPTED so the NAS can reboot unattended
  # (no passphrase prompt). To encrypt instead, add these to `zpool create`:
  #
  #        -O encryption=aes-256-gcm \
  #        -O keyformat=passphrase \
  #        -O keylocation=prompt \
  #
  # You'll then be prompted for the passphrase at boot (or point keylocation at a
  # keyfile on the boot disk / a USB key for semi-unattended boots).
}
