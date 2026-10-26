{ config, pkgs, lib, ... }:

# Flatpak support with the Flathub remote pre-registered, so `flatpak install`
# works out of the box with no manual setup.

{
  services.flatpak.enable = true;

  # Flatpak GUI apps talk to the system through XDG desktop portals. The desktop
  # module enables the portal + the wlroots backend (screenshots/screencast); add
  # the GTK backend here for file choosers / settings, which most Flatpaks use.
  # (Set portal.enable here too so Flatpak still has a portal even if you run
  # headless and remove the desktop module.)
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  # Pick any available portal backend by default (silences "no suitable backend"
  # from newer xdg-desktop-portal and lets Flatpak file choosers work).
  xdg.portal.config.common.default = "*";

  # Register the Flathub remote automatically (system-wide) once the network is
  # up. `--if-not-exists` makes this idempotent, so it's a no-op on later boots.
  systemd.services.flathub-remote = {
    description = "Register the Flathub Flatpak remote";
    after = [ "network-online.target" "flatpak-system-helper.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Retry a few times if DNS/network isn't ready yet at first boot (the
      # network-online target is best-effort under static scripted networking).
      Restart = "on-failure";
      RestartSec = "30s";
    };
    unitConfig = {
      StartLimitIntervalSec = "300";
      StartLimitBurst = 5;
    };
    script = ''
      flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Usage:
  #   flatpak install flathub org.videolan.VLC     # system-wide (uses polkit/sudo)
  #   flatpak run org.videolan.VLC
  #   flatpak update                                # update installed apps
  # Prefer a per-user install? `flatpak --user remote-add --if-not-exists flathub
  # https://flathub.org/repo/flathub.flatpakrepo` then `flatpak --user install ...`.
}
