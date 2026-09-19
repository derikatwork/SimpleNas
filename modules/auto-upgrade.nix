{ config, pkgs, lib, ... }:

# Weekly automatic updates, Friday 02:00 (server local time = America/Los_Angeles).
#
# NOTE on "security" updates: NixOS has no security-only channel like Debian's
# unattended-upgrades. The equivalent is to rebuild against the PINNED STABLE
# branch (nixos-25.11, set in flake.nix), which receives conservative backports
# — security fixes and important bugfixes — without feature churn. Each run below
# refreshes the nixpkgs input to the latest of that branch and rebuilds.

{
  system.autoUpgrade = {
    enable = true;

    # Rebuild from this flake. Points at the GitHub repo so the box pulls the
    # committed config; `--update-input nixpkgs` then bumps nixpkgs to the latest
    # nixos-25.11 revision at build time (that's where the security backports
    # land). To upgrade to a NEW release later, change the branch in flake.nix.
    #
    # Prefer a local checkout instead? Set:
    #   flake = "/etc/nixos";   # (a git clone of this repo)
    flake = "github:derikatwork/SimpleNas#simplenas";

    flags = [
      "--update-input" "nixpkgs"   # pull latest nixos-25.11 (security backports)
      "--no-write-lock-file"       # source is immutable (fetched), don't write lock
      "-L"                         # verbose build logs in the journal
    ];

    # Friday 02:00 exactly (systemd OnCalendar syntax), no random jitter.
    dates = "Fri *-*-* 02:00:00";
    randomizedDelaySec = "0";

    # If the box was off at 02:00 Friday, run at the next boot instead of skipping.
    persistent = true;

    # Apply the new system without rebooting. Userspace security fixes take effect
    # immediately; a new kernel/microcode only becomes active after the next
    # reboot. To let it auto-reboot when a reboot is required, use instead:
    #   allowReboot = true;
    #   rebootWindow = { lower = "02:00"; upper = "04:00"; };
    allowReboot = false;
  };

  # Trim old generations so weekly rebuilds don't fill the boot disk over time.
  # (Complements nix.gc in base.nix.)
}
