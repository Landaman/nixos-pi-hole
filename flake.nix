{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
  outputs =
    {
      nixpkgs,
      nixos-hardware,
      ...
    }:
    let
      # Helper to make multiple pi systems with the same config
      mkPiHole =
        specialArgs:
        nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = specialArgs // {
            hardware = nixos-hardware;
          };
          modules = [
            ./pi/hardware-pi02.nix
            ./pi-hole-configuration.nix
          ];
        };

    in
    {
      nixosConfigurations = {
        cross = mkPiHole {
          imageName = "cross";
          systemName = "cross";
          network = {
          };
        };
      };
    };
}
