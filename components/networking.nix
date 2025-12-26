{
  systemName,
  secrets,
  lib,
  ...
}:
let
  systemSecrets = secrets."${systemName}";
  networkSecrets = secrets.networks.${systemSecrets.network};
in
{
  networking = {
    hostName = "${systemName}";

    defaultGateway = networkSecrets.defaultGateway;
    nameservers = [ networkSecrets.defaultGateway ];
    interfaces."wlan0".ipv4.addresses = lib.mkIf (systemSecrets ? ipAddress) [
      {
        address = systemSecrets.ipAddress;
        prefixLength = networkSecrets.ipPrefixLength;
      }
    ];
    useDHCP = true; # This automatically doesn't apply if the above is set
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
      networks = {
        "${networkSecrets.ssid}".psk = networkSecrets.password;
      };
    };
  };

  services.timesyncd.enable = true;
}
