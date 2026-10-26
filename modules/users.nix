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
      "wheel"   # sudo
    ];
    shell = pkgs.bash;

    # No password is shipped in this repo on purpose (a committed "changeme" is a
    # known credential — and with desktop auto-login enabled it would hand anyone
    # at the console, or on the server's IPMI/BMC remote console, a sudo-capable
    # session). The account therefore starts with NO valid password: greetd
    # auto-login still works, but sudo won't until you set one.
    #
    # Set it during install (the ISO installer runs `passwd nas` for you) or after
    # first boot:  passwd nas
    #
    # Better for production: point at a hashed password file (never commit the
    # hash itself), e.g.:
    #   hashedPasswordFile = "/etc/nixos/secrets/nas.hash";   # mkpasswd -m sha-512 > it
    # SSH key login is recommended over passwords for remote access:
    # openssh.authorizedKeys.keys = [
    #   "ssh-ed25519 AAAA... you@host"
    # ];
  };

  # wheel members must enter their password for sudo (so an unattended console/BMC
  # session can't escalate until a password is set). Leave this on.
  security.sudo.wheelNeedsPassword = true;
}
