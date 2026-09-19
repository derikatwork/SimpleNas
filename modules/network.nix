{ config, pkgs, lib, ... }:

# Networking: DHCP via NetworkManager, Tailscale (with Tailscale SSH), and a
# firewall that trusts the tailnet.

{
  # Simple, reliable networking. NetworkManager handles wired + wireless.
  networking.networkmanager.enable = true;

  # ── Tailscale ───────────────────────────────────────────────────────────────
  services.tailscale = {
    enable = true;

    # Tailscale SSH: authenticate SSH over the tailnet via Tailscale ACLs,
    # so you don't manage keys/passwords for remote login. After first boot run:
    #   sudo tailscale up --ssh
    # (or just `sudo tailscale up` and enable SSH in the admin console).
    extraUpFlags = [ "--ssh" ];

    # `both` opens the firewall for Tailscale and, when this node is a
    # subnet-router/exit-node, enables IP forwarding. Harmless otherwise.
    useRoutingFeatures = "both";

    # ── Subnet router / exit node (optional; not enabled by default) ──────────
    # To advertise your LAN or act as a VPN exit node, run on the box:
    #   sudo tailscale up --ssh --advertise-routes=192.168.1.0/24
    #   sudo tailscale up --ssh --advertise-exit-node
    # then approve the routes in the Tailscale admin console.
  };

  # ── Firewall ────────────────────────────────────────────────────────────────
  networking.firewall = {
    enable = true;

    # Trust anything arriving over the Tailscale interface. This is what lets
    # Tailscale SSH (and any tailnet-only services) work without poking
    # individual ports in the LAN firewall.
    trustedInterfaces = [ "tailscale0" ];

    # Recommended by Tailscale for smoother NAT traversal.
    checkReversePath = "loose";

    # No LAN ports opened by default — access is via Tailscale.
    # If you enable Samba/NFS in modules/nas.nix and want them on the LAN,
    # open the relevant ports there.
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # Regular SSH daemon (keys only). Useful as a fallback / for LAN access.
  # Tailscale SSH does not require this, but it's a sane safety net.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
