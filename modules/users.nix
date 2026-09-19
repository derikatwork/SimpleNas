{ config, pkgs, lib, ... }:

# User accounts. Adjust the username and, importantly, set an initial password
# and/or SSH keys before you rely on remote access.

let
  # TODO: change to your preferred username. If you change it, also update
  # the `username` let-binding in modules/desktop.nix (greetd auto-login user).
  username = "nas";
in
{
  users.users.${username} = {
    isNormalUser = true;
    description = "SimpleNAS primary user";
    extraGroups = [
      "wheel"           # sudo
      "networkmanager"  # manage networking
    ];
    shell = pkgs.bash;

    # Set a real password after install with `passwd`, or replace this with a
    # hashed value (mkpasswd -m sha-512). Change it immediately!
    initialPassword = "changeme";

    # Recommended: log in over SSH with keys instead of a password.
    # openssh.authorizedKeys.keys = [
    #   "ssh-ed25519 AAAA... you@host"
    # ];
  };

  # Passwordless-sudo is off by default; wheel members are prompted for their
  # password. Set to true only if you understand the tradeoff.
  security.sudo.wheelNeedsPassword = true;
}
