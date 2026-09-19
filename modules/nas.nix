{ config, pkgs, lib, ... }:

# File-sharing services. Per the build plan, all three access methods are
# supported, but SMB and NFS are left COMMENTED OUT for now — access is over
# Tailscale until you're ready to expose LAN shares. Uncomment a block, adjust
# paths/hosts, and rebuild to turn one on.
#
# Reminder: your data lives on the imported pool, under /mnt/divine-storm/...
# (run `zfs list -o name,mountpoint` to see exact paths). To make this a
# client-transparent swap, reuse your old TrueNAS share NAMES and point each at
# the matching dataset path below.

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
  #     data = {                       # <- use your old TrueNAS share name here
  #       "path" = "/mnt/divine-storm/data";
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
  #   # Lock the share to your LAN subnet.
  #   exports = ''
  #     /mnt/divine-storm/data  192.168.0.0/24(rw,sync,no_subtree_check,root_squash)
  #   '';
  # };
  # # Open NFS ports on the LAN when the server is enabled:
  # networking.firewall.allowedTCPPorts = [ 2049 ];
  # networking.firewall.allowedUDPPorts = [ 2049 ];
}
