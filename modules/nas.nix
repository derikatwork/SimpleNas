{ config, pkgs, lib, ... }:

# File-sharing services. Per the build plan, all three access methods are
# supported, but SMB and NFS are left COMMENTED OUT for now — access is over
# Tailscale until you're ready to expose LAN shares. Uncomment a block, adjust
# paths/hosts, and rebuild to turn one on.
#
# Reminder: your data lives on ZFS datasets you created (e.g. tank/data mounted
# at /srv/data). Point the shares below at those mountpoints.

{
  # ── Samba / SMB (Windows, macOS, Linux) ─────────────────────────────────────
  # services.samba = {
  #   enable = true;
  #   openFirewall = true;   # opens 139/445 on the LAN
  #   settings = {
  #     global = {
  #       "workgroup" = "WORKGROUP";
  #       "server string" = "SimpleNAS";
  #       "map to guest" = "never";
  #     };
  #     data = {
  #       "path" = "/srv/data";
  #       "browseable" = "yes";
  #       "read only" = "no";
  #       "valid users" = "nas";
  #       "create mask" = "0644";
  #       "directory mask" = "0755";
  #     };
  #   };
  # };
  # # Advertise the server to Windows/macOS network browsing:
  # services.samba-wsdd = {
  #   enable = true;
  #   openFirewall = true;
  # };
  # # Set each Samba user's password once with: sudo smbpasswd -a nas

  # ── NFS (Linux/Unix clients, VMs) ───────────────────────────────────────────
  # services.nfs.server = {
  #   enable = true;
  #   # Lock the share to your LAN subnet (change 192.168.1.0/24 to match yours).
  #   exports = ''
  #     /srv/data  192.168.1.0/24(rw,sync,no_subtree_check,root_squash)
  #   '';
  # };
  # # Open NFS ports on the LAN when the server is enabled:
  # networking.firewall.allowedTCPPorts = [ 2049 ];
  # networking.firewall.allowedUDPPorts = [ 2049 ];
}
