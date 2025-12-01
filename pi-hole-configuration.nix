{
  pkgs,
  lib,
  systemName,
  secrets,
  tailscaleLocationTag,
  ...
}:
let
  systemSecrets = secrets."${systemName}";
in
{
  system.stateVersion = "26.05";

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  environment.systemPackages = with pkgs; [
    git
  ];

  services.openssh.enable = true; # Enable this otherwise you can't sign in right away
  users = {
    mutableUsers = false;

    users."${secrets.user.name}" = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      password = secrets.user.password;
      openssh.authorizedKeys.keys = secrets.user.sshPublicKeys;
    };
  };

  networking = {
    hostName = "${systemName}-pi-hole";

    defaultGateway = systemSecrets.network.defaultGateway;
    nameservers = [ systemSecrets.network.defaultGateway ];
    interfaces."wlan0".ipv4.addresses = [
      {
        address = systemSecrets.network.ipAddress;
        prefixLength = systemSecrets.network.ipPrefixLength;
      }
    ];
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
      networks = {
        "${systemSecrets.network.ssid}".psk = systemSecrets.network.password;
      };
    };
  };

  services.timesyncd.enable = true;

  environment.etc."tailscale-auth-key".text = secrets.tailscale.authKey;

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "/etc/tailscale-auth-key";
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--advertise-tags=tag:${tailscaleLocationTag}"
    ];
    extraSetFlags = [
      "--advertise-exit-node"
      "--advertise-routes=${lib.concatStringsSep "," systemSecrets.network.accessibleSubnets}"
    ];
  };

  nix.settings = {
    experimental-features = lib.mkDefault "nix-command flakes";
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
