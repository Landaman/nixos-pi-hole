{
  pkgs,
  lib,
  systemName,
  network,
  ...
}:
{
  system.stateVersion = "26.05";

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  services.openssh.enable = true; # Enable this otherwise you can't sign in right away
  users = {
    mutableUsers = false;

    users.iwright = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = "$y$j9T$i1FG4UrC2TmqmXEbQBBzj0$RBKb/y/fgvKY7.3ZeoovPtVaDqOWa7l2XIbx0cU6ob1";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC9MRWIGgfFHGdezqhKKljyo9HTGU+YWck+PlFHTy4oCNJEfBTOnMrTj7tyqD5pLX5T+GdbZVfZWhKax7wz2co/+PDsNeN2PPpeM9DI+vQXCs19J7pKMQJ4extcDq+1KcoVDKmtOCJ2gRKFqG/qxSNPBHGaoJN4eilpcJt6ApiRAmJRlU6S8gltpp3cJWKS220cEGm2BWnBTsfcrovf6ni+rWuQVbJaq3P2NejEBYpaDwLC7z8JbewUegGaC/1Xi80z9NdMYW4dub7gygxxRESjYPMxzwkK1JhWOhDqSRF1MKWY/pnhVHNmxjYgL/mVhHy3KIHdtSgEoZRX4zEwWYwTsIly/c4OkSa8bR+E3Jh9gJsCbSvEwpOZ+iT1WRvvGDgMJ5zPsyhJnGqEtUGzsMxNjm7DfXL5IhlTARodqSq4hwMLZjt3oBHm7YqL2QllS3weoaflzqPVvsXihw0FSnQdRHYaRdNBhKl+V8l+FSS0ubnfEi3Eqp719v/3PWZzNGM= ianwright@autoreg-3322860.dyn.wpi.edu"
      ];
    };
  };

  networking.hostName = "${systemName}-pi-hole";
  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
      networks = {
        "${network.SSID}".psk = network.password;
      };
    };
  };

  services.timesyncd.enable = true;

  nix.settings = {
    experimental-features = lib.mkDefault "nix-command flakes";
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
