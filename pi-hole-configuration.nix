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

  systemd.services.tailscaled-generate-auth-key = {
    description = "Generate a tailscale auth key if necessary";

    before = [ "tailscaled-autoconnect.service" ];
    wantedBy = [ "tailscaled-autoconnect.service" ];
    after = [
      "tailescaled.service"
    ];
    wants = [
      "tailescaled.service"
    ];
    serviceConfig = {
      Type = "oneshot";
    };

    path = with pkgs; [
      tailscale
      jq
      curl
    ];
    script = ''
      wait_for_time() {
        local i=0

        while (( i < 60 )); do
          local year
          year=$(date +%Y)

          if (( year > 2000 )); then
            return 0
          fi

          sleep 1
          ((i++))
        done

        echo "Error: Time did not sync" >&2
        exit 1
      }

      wait_for_time

      state="$(tailscale status --json --peers=false | jq -r '.BackendState')"

      # No need to do anything if we're already up
      if [[ ! "$state" =~ ^(NeedsLogin|NeedsMachineAuth|Stopped)$ ]]; then
        echo "Tailscale is already authenticated. Nothing to do."
        exit 0
      fi

      accessToken="$(curl --request POST \
        --url https://api.tailscale.com/api/v2/oauth/token \
        --header "Authorization: Basic $(echo -n "${secrets.tailscale.clientID}:${secrets.tailscale.clientSecret}" | base64 -w 0)" \
        --header 'content-type: application/x-www-form-urlencoded' \
        --data grant_type=client_credentials \
        --data scope=auth_keys | jq -r '.access_token')"

      deviceKey="$(curl 'https://api.tailscale.com/api/v2/tailnet/${secrets.tailscale.tailnet}/keys' \
        --request POST \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer $accessToken" \
        --data '{
        "keyType": "auth",
        "description": "${systemName}",
        "capabilities": {
          "devices": {
            "create": {
              "reusable": false,
              "ephemeral": false,
              "preauthorized": false,
              "tags": [
                "tag:${systemSecrets.tailscale.locationTag}",
                "tag:pi-hole"
              ]
            }
          }
        },
        "expirySeconds": 60
      }' | jq -r '.key')"

      echo "$deviceKey" > /etc/tailnet-auth-key
      echo "Wrote device key to /etc/tailnet-auth-key"
    '';
  };

  services.tailscale = rec {
    enable = true;
    openFirewall = true;
    authKeyFile = "/etc/tailnet-auth-key";
    useRoutingFeatures = "server";
    extraSetFlags = [
      "--advertise-exit-node"
      "--advertise-routes=${lib.concatStringsSep "," systemSecrets.tailscale.accessibleSubnets}"
    ];
    extraUpFlags = extraSetFlags; # Without this, you can't use up after set runs
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

    path = with pkgs; [
      tailscale
      jq
    ];
    script = ''
      status="$(tailscale serve status --json | jq -r 'getpath(["TCP","443","HTTPS"]) // empty')"
       if [ $status = "True" ]; then
         echo "Pi-Hole web UI is already being served over Tailscale"
         exit 0
       fi

       tailscale serve --bg https+insecure://localhost:443
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
