{
  pkgs,
  lib,
  systemName,
  secrets,
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
    hostName = "${systemName}";

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
      "--advertise-tags=tag:${systemSecrets.tailscale.locationTag}"
    ];
    extraSetFlags = [
      "--advertise-exit-node"
      "--advertise-routes=${lib.concatStringsSep "," systemSecrets.tailscale.accessibleSubnets}"
    ];
  };

  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallWebserver = true;
    queryLogDeleter.enable = true;
    lists = [
      {
        enabled = true;
        url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.plus.txt";
        type = "block";
        description = "Hagezi Mutli PRO++";
      }
    ];

    settings = {
      dns = {
        listeningMode = "ALL";
        upstreams = [
          "9.9.9.9"
          "149.112.112.112"
          "2620:fe::fe"
          "2620:fe::9"
          systemSecrets.network.defaultGateway
        ];
      };
    };
  };

  services.pihole-web = {
    enable = true;
    ports = [
      {
        port = 443;
        ssl = true;
      }
    ];
  };

  # One-shot task to make sure we're serving the Pi-Hole web UI over Tailscale
  systemd.services.pi-hole-tailscale-serve = {
    description = "Serve the Pi-Hole web UI over Tailscale";

    after = [
      "tailscaled-autoconnect.service"
      "pihole-ftl.service"
    ];
    wants = [
      "tailscaled-autoconnect.service"
      "pihole-ftl.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";
    script = with pkgs; ''
      status="$(${tailscale}/bin/tailscale serve status --json | ${jq}/bin/jq -r 'getpath(["TCP","443","HTTPS"]) // empty')"
       if [ $status = "True" ]; then
         echo "Pi-Hole web UI is already being served over Tailscale"
         exit 0
       fi

       ${tailscale}/bin/tailscale serve --bg https+insecure://localhost:443
    '';
  };

  nix.settings = {
    experimental-features = lib.mkDefault "nix-command flakes";
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
