{
  description = "SimpleNAS - a NixOS NAS with ZFS, Tailscale, and a labwc (Wayland) desktop";

  inputs = {
    # Pinned to a stable NixOS release for reproducibility.
    # Bump this (and run `nix flake update`) when you want to move to a newer release.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        # The installed NAS system. Host name here must match
        # `networking.hostName` in the host config.
        simplenas = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/simplenas/configuration.nix
          ];
        };

        # A bootable live ISO that carries this repo and a guided installer.
        installer = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./iso/configuration.nix
          ];
        };
      };

      # Convenience build targets:
      #   nix build .#iso   ->  result/iso/simplenas-installer.iso
      packages.${system} = {
        iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        default = self.nixosConfigurations.installer.config.system.build.isoImage;
      };
    };
}
