{ ... }:
{
  # Packages that all systems should have
  imports = [
    ./components/nix-settings.nix
    ./components/account.nix
    ./components/networking.nix
    ./components/tailscale.nix
  ];
}
