{ config, pkgs, lib, ... }:

{
  imports = [
    # Hardware scan. Generate this on the target machine with:
    #   nixos-generate-config --root /mnt
    # then copy the result over this placeholder (see hardware-configuration.nix).
    ./hardware-configuration.nix

    # Feature modules.
    ../../modules/base.nix
    ../../modules/boot.nix
    ../../modules/zfs.nix
    ../../modules/network.nix
    ../../modules/desktop.nix
    ../../modules/users.nix
    ../../modules/nas.nix
    ../../modules/flatpak.nix
    ../../modules/auto-upgrade.nix
  ];

  # ── Identity ────────────────────────────────────────────────────────────────
  # Deliberately NOT "truenas". Change to taste; hostName must match the attr
  # name in flake.nix (rename both together if you change it).
  networking.hostName = "simplenas";

  # Required by ZFS: a unique 8-hex-digit id. Generated for this build; keep it
  # unique per machine. Regenerate with: head -c4 /dev/urandom | od -A none -t x4
  networking.hostId = "5af23065";

  # ── Hardware: CPU ─────────────────────────────────────────────────────────────
  # Intel Xeon E5640 -> load Intel CPU microcode updates.
  hardware.cpu.intel.updateMicrocode = true;

  # ── Locale / time ───────────────────────────────────────────────────────────
  # US Pacific.
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # The release you first installed with. Do NOT change this on an existing
  # system just to match a newer nixpkgs — it guards stateful defaults.
  system.stateVersion = "25.11";
}
