{ config, pkgs, lib, ... }:

# ZFS support + maintenance for a DROP-IN migration from TrueNAS SCALE.
#
# The existing pool "divine-storm" is IMPORTED as-is (no data is created or
# destroyed here). ZFS locates pool members by on-disk labels, so it does not
# matter that Linux may rename the disks (sda/sdc/sdd/sde under TrueNAS).

{
  boot.supportedFilesystems.zfs = true;

  # Don't force-import a pool that another system might still own. See the
  # migration note below about exporting the pool from TrueNAS first.
  boot.zfs.forceImportRoot = false;

  # Import the existing data pool at boot. Its datasets mount at the mountpoints
  # stored in the pool itself (TrueNAS SCALE stores these under /mnt, e.g.
  # /mnt/divine-storm/...), so shares and paths line up without extra config.
  boot.zfs.extraPools = [ "divine-storm" ];

  # Weekly scrub to catch/repair bit-rot (replaces TrueNAS's scrub task).
  services.zfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  # Periodic TRIM (no-op on spinning disks).
  services.zfs.trim.enable = true;

  # Automatic snapshots for any dataset with `com.sun:auto-snapshot=true`.
  # NOTE: your existing TrueNAS snapshots are part of the pool and import with
  # it, untouched. TrueNAS's *scheduled* snapshot tasks do NOT carry over; to
  # have NixOS take over snapshotting a dataset, tag it once, e.g.:
  #   zfs set com.sun:auto-snapshot=true divine-storm/<dataset>
  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 4;   # every 15 min, keep 4
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 3;
  };

  # ── Migrating the pool from TrueNAS SCALE (do this once) ─────────────────────
  # 1. On the TrueNAS box, stop SMB/NFS/apps, then cleanly export the pool:
  #        zpool export divine-storm
  #    (or just shut TrueNAS down gracefully). This releases TrueNAS's hostid
  #    claim so NixOS can import without a forced override.
  #
  # 2. Install NixOS onto the BOOT disk only (the old TrueNAS boot device).
  #    DO NOT touch the four pool disks. Identify disks by stable id first:
  #        ls -l /dev/disk/by-id/
  #        lsblk -o NAME,SIZE,MODEL,SERIAL
  #
  # 3. Boot NixOS. `boot.zfs.extraPools` imports "divine-storm" automatically.
  #    Verify:
  #        zpool status divine-storm
  #        zfs list -o name,mountpoint
  #
  #    If the pool was NOT cleanly exported, the first import fails with an
  #    "owned by another system" error. Import once by hand, then reboot:
  #        zpool import -f divine-storm
  #
  #    If datasets land at unexpected paths, check/adjust the stored mountpoint:
  #        zfs get mountpoint divine-storm
  #
  # ── Encryption ───────────────────────────────────────────────────────────────
  # Your pool is unencrypted, so nothing extra is needed. (If you ever add
  # native ZFS encryption, you'd load the key at boot via a small service.)
}
