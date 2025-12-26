{
  pkgs,
  lib,
  systemName,
  config,
  secrets,
  ...
}:
let
  systemSecrets = secrets."${systemName}";
  networkSecrets = secrets.networks.${systemSecrets.network};
in
{
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
          networkSecrets.defaultGateway
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

  services.tailscale.tags = lib.mkBefore [ "tag:pi-hole" ];

  # One-shot task to make sure we're serving the Pi-Hole web UI over Tailscale, if it's enabled
  systemd.services.pi-hole-tailscale-serve = lib.mkIf config.services.tailscale.enable {
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
}
