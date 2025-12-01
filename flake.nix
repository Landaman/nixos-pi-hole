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
      secrets = builtins.fromJSON (builtins.readFile ./secrets.json);

      # Helper to make multiple pi systems with the same config
      mkPiHole =
        specialArgs:
        nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = specialArgs // {
            inherit secrets;
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
        nine-cross = mkPiHole rec {
          systemName = "nine-cross";
          imageName = systemName;
          tailscale-tag = systemName;
        };
      };
    };
}
