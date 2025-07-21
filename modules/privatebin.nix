{
  config,
  lib,
  ...
}:
{
  options.secshell.privatebin = {
    enable = lib.mkEnableOption "privatebin";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "privatebin.${toString config.networking.fqdn}";
    };
  };

  config = lib.mkIf config.secshell.privatebin.enable {
    # php-fpm[6116]: free(): invalid pointer
    environment.memoryAllocator.provider = "libc";
    security.forcePageTableIsolation = false;

    services = {
      privatebin = {
        enable = true;
        virtualHost = config.secshell.privatebin.domain;
        enableNginx = true;
      };
      nginx = {
        virtualHosts."${toString config.secshell.privatebin.domain}" = {
          serverName = toString config.secshell.privatebin.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString config.secshell.privatebin.domain;
          forceSSL = true;
        };
      };
    };
    security.acme.certs."${toString config.secshell.privatebin.domain}" = { };
  };
}
