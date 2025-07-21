{
  config,
  lib,
  ...
}:
{
  options.secshell.cryptpad = {
    enable = lib.mkEnableOption "cryptpad";
    # for more information regarding domain setup see
    # https://docs.cryptpad.org/en/dev_guide/general.html
    domain = lib.mkOption {
      type = lib.types.str;
      default = "ucryptpad.${toString config.networking.fqdn}";
    };
    sandboxDomain = lib.mkOption {
      type = lib.types.str;
      default = "cryptpad.${toString config.networking.fqdn}";
    };
    internal_port = lib.mkOption { type = lib.types.port; };
    internal_ws_port = lib.mkOption { type = lib.types.port; };
  };

  config = lib.mkIf config.secshell.cryptpad.enable {
    services = {
      cryptpad = {
        enable = true;
        configureNginx = true;
        settings = {
          httpAddress = "127.0.0.1";
          httpPort = config.secshell.cryptpad.internal_port;
          websocketPort = config.secshell.cryptpad.internal_ws_port;
          httpUnsafeOrigin = "https://${config.secshell.cryptpad.domain}";
          httpSafeOrigin = "https://${config.secshell.cryptpad.sandboxDomain}";
        };
      };
      # use ACME DNS-01 challenge
      nginx.virtualHosts."${config.secshell.cryptpad.domain}" = {
        enableACME = false;
        useACMEHost = config.secshell.cryptpad.domain;
      };
    };
    security.acme.certs."${config.secshell.cryptpad.domain}" = {
      extraDomainNames = [ config.secshell.cryptpad.sandboxDomain ];
    };
  };
}
