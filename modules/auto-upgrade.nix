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

    # Rebuild from the LOCAL checkout of this repo at /etc/nixos. Local is the
    # robust default: it needs no network credentials, so it works even if your
    # GitHub repo is PRIVATE (fetching a private flake from github would fail on a
    # headless box). `--update-input nixpkgs` then bumps nixpkgs to the latest
    # nixos-25.11 revision at build time — that's where the security backports land.
    #
    # This requires /etc/nixos to be a git clone of this repo (the install steps
    # put it there). Edits to existing tracked files are picked up automatically;
    # if you ADD a new file, `git add` it or nix won't see it.
    #
    # Public repo and prefer pulling from GitHub instead? Use:
    #   flake = "github:derikatwork/SimpleNas#simplenas";
    flake = "/etc/nixos#simplenas";

    flags = [
      "--update-input" "nixpkgs"   # pull latest nixos-25.11 (security backports)
      "--no-write-lock-file"       # don't rewrite/commit flake.lock from the timer
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
