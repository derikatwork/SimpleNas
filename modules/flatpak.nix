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
