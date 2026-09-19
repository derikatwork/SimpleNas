{ config, pkgs, lib, ... }:

# Networking: a static LAN address (reproducing the old NAS), Tailscale with
# Tailscale SSH, and a firewall that trusts the tailnet.

let
  # Two NICs, mirroring the previous NAS:
  #   access  -> 192.168.0.222  (primary; carries the default route + services)
  #   mgmt    -> 192.168.0.228  (management)
  # ⚠ TODO: set these to your real interface names. They are NOT known ahead of
  # time and are NOT the TrueNAS "sdX" naming. Find them on the installed system:
  #   ip -o link      (look for "en..." / "eth..." devices, e.g. eno1, eno2)
  # If a name here is wrong, that interface's static IP won't apply. Confirm
  # which physical port is access vs management and map accordingly.
  accessNic = "eno1";   # -> 192.168.0.222
  mgmtNic   = "eno2";   # -> 192.168.0.228
in
{
  # Static IPv4 on both NICs.
  networking.useDHCP = false;
  networking.interfaces.${accessNic}.ipv4.addresses = [
    { address = "192.168.0.222"; prefixLength = 24; }
  ];
  networking.interfaces.${mgmtNic}.ipv4.addresses = [
    { address = "192.168.0.228"; prefixLength = 24; }
  ];

  # Pin the default route to the ACCESS NIC so outbound traffic is deterministic
  # on this multi-homed host (both NICs share the 192.168.0.0/24 subnet).
  # ⚠ TODO: confirm the gateway/DNS (192.168.0.1 is the common default).
  networking.defaultGateway = { address = "192.168.0.1"; interface = accessNic; };
  networking.nameservers = [ "192.168.0.1" "1.1.1.1" ];

  # NOTE: both NICs on one subnet is fine here — `checkReversePath = "loose"`
  # below keeps replies to the management IP working despite the single default
  # route (Linux rp_filter would otherwise drop asymmetric return traffic).

  # ── DHCP fallback ────────────────────────────────────────────────────────────
  # Unsure of interface names, or want the router to assign addresses? Comment
  # out the static block above and use:
  #   networking.useDHCP = true;
  # (then set DHCP reservations on your router to keep the addresses stable).

  # ── Tailscale ───────────────────────────────────────────────────────────────
  services.tailscale = {
    enable = true;
    # Tailscale SSH: SSH auth over the tailnet via Tailscale ACLs. After first
    # boot, authenticate once with:  sudo tailscale up --ssh
    extraUpFlags = [ "--ssh" ];
    useRoutingFeatures = "both";
    # Subnet router / exit node are opt-in at `tailscale up` time; see README.
  };

  # ── Firewall ────────────────────────────────────────────────────────────────
  networking.firewall = {
    enable = true;
    # Trust the tailnet interface so Tailscale SSH and tailnet-only services work
    # without opening LAN ports.
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose";
    # No LAN ports opened by default (shares are Tailscale-only for now). When you
    # enable Samba/NFS in modules/nas.nix, open their ports there.
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # Regular SSH (keys only) as a LAN fallback alongside Tailscale SSH.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
