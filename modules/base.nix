{ config, pkgs, lib, ... }:

# Core system: Nix settings, shell, editor, and a lean set of NAS-friendly
# command-line tools.

{
  # Enable flakes + the new nix CLI (this repo is a flake).
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Automatic garbage collection + store optimisation to keep the boot disk tidy.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;

  # Allow unfree packages (needed for some firmware and, if you add it later,
  # things like Plex). Harmless to leave on.
  nixpkgs.config.allowUnfree = true;

  # ── Shell ──────────────────────────────────────────────────────────────────
  # Bash as the default login shell (explicitly enabled + completion).
  programs.bash.completion.enable = true;
  users.defaultUserShell = pkgs.bash;

  # ── Editor ─────────────────────────────────────────────────────────────────
  programs.nano.enable = true;
  environment.variables.EDITOR = "nano";

  # ── Handy CLI tooling for a NAS ────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    nano
    git
    wget
    curl
    htop
    tmux
    tree
    rsync
    pciutils        # lspci
    usbutils        # lsusb
    lm_sensors      # temperatures / fan speeds
    smartmontools   # SMART drive health (smartctl)
    hdparm
  ];

  # Monitor drive health in the background and log SMART warnings to the journal.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # Compressed RAM swap. No disk partition needed; gives the box headroom so a
  # memory spike (ZFS ARC + services) doesn't OOM-kill processes on old hardware.
  zramSwap.enable = true;

  # Keep clocks correct (needed for the scheduled auto-upgrade, TLS, logs).
  # Enabled by default on NixOS, but stated explicitly so it's obvious.
  services.timesyncd.enable = true;
}
