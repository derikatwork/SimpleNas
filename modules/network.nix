{ config, pkgs, lib, ... }:

# Networking: a static LAN address (reproducing the old NAS), Tailscale with
# Tailscale SSH, and a firewall that trusts the tailnet.

let
  # ⚠ TODO: set these to your two wired NIC names. They are NOT known ahead of
  # time and are NOT the TrueNAS "sdX" naming. Find them on the installed system:
  #   ip -o link      (look for "en..." / "eth..." devices, e.g. eno1, eno2)
  # If a name here is wrong, that interface's static IP won't apply (DHCP
  # fallback below). Map each name to the correct IP once you know which is which.
  nic1 = "eno1";   # -> 192.168.0.222
  nic2 = "eno2";   # -> 192.168.0.228
in
{
  # Static IPv4 on both NICs, mirroring the previous NAS.
  networking.useDHCP = false;
  networking.interfaces.${nic1}.ipv4.addresses = [
    { address = "192.168.0.222"; prefixLength = 24; }
  ];
  networking.interfaces.${nic2}.ipv4.addresses = [
    { address = "192.168.0.228"; prefixLength = 24; }
  ];
  # ⚠ TODO: confirm these match your network (192.168.0.1 is the common default).
  networking.defaultGateway = "192.168.0.1";
  networking.nameservers = [ "192.168.0.1" "1.1.1.1" ];

  # NOTE: both NICs are on the same 192.168.0.0/24 subnet (as on the old box).
  # That works, but two interfaces on one subnet can cause ARP/return-path
  # quirks. If you don't actually need two addresses, drop nic2 and just use
  # nic1, or bond them. `checkReversePath = "loose"` below keeps this tolerant.

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
