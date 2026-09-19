{ config, pkgs, lib, ... }:

# Minimal Wayland desktop: the labwc compositor (Openbox-style, in the Blackbox
# family), with greetd auto-logging straight into the labwc session at boot.
#
# NOTE: NixOS removed the original Blackbox window-manager module (Blackbox has
# been unmaintained upstream since ~2005). labwc gives the same lightweight,
# right-click-menu feel on a modern Wayland stack.
#
# The desktop is NON-ESSENTIAL to the NAS. On old server GPUs (ASPEED/Matrox),
# Wayland/labwc may not start; if so the box is still fully functional — reach it
# via SSH/Tailscale or a text console (Ctrl+Alt+F2). To run fully headless,
# remove this module from configuration.nix's imports and rebuild.

let
  # Must match the account in modules/users.nix.
  username = "nas";
in
{
  # labwc Wayland compositor. Installs the package and registers the session.
  programs.labwc.enable = true;

  # GPU / hardware acceleration for Wayland.
  hardware.graphics.enable = true;

  # Session plumbing most GUI apps expect.
  security.polkit.enable = true;
  services.dbus.enable = true;

  # Screenshot / screencast portal for wlroots-based compositors (labwc is one).
  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  # greetd: auto-login into labwc at boot; show a tiny greeter only on logout.
  services.greetd = {
    enable = true;
    settings = {
      # Runs once at boot with no prompt -> straight into the desktop.
      initial_session = {
        command = "labwc";
        user = username;
      };
      # If you log out, a minimal text greeter lets you log back in.
      default_session = {
        command = "${lib.getExe pkgs.greetd.tuigreet} --time --cmd labwc";
        user = "greeter";
      };
    };
  };

  # Keyboard layout for the Wayland session (XKB). TODO: change if not US.
  environment.sessionVariables.XKB_DEFAULT_LAYOUT = "us";

  # A usable minimal Wayland environment on top of the bare compositor.
  # labwc ships with XWayland, so X-only apps still run.
  environment.systemPackages = with pkgs; [
    foot            # Wayland terminal
    fuzzel          # application launcher (dmenu-like)
    swaybg          # set a wallpaper
    swaylock        # lock screen
    grim            # screenshots
    slurp           # region selection for grim
    wl-clipboard    # clipboard integration
    pcmanfm         # file manager
  ];
}
