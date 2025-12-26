{
  secrets,
  ...
}:
{
  services.openssh.enable = true;
  users = {
    mutableUsers = false;

    users."${secrets.user.name}" = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      password = secrets.user.password;
      openssh.authorizedKeys.keys = secrets.user.sshPublicKeys;
    };
  };
}
