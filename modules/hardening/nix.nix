{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.secshell.hardening {
    nix.settings.allowed-users = [ "@wheel" ];
  };
}
