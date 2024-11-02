{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.secshell.zammad = {
    enable = lib.mkEnableOption "zammad";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "support.${toString config.networking.fqdn}";
      defaultText = "support.\${toString config.networking.fqdn}";
    };
    ports = {
      http = lib.mkOption {
        type = lib.types.port;
        default = 3000;
      };
      websocket = lib.mkOption {
        type = lib.types.port;
        default = 6042;
      };
    };
  };
  config = lib.mkIf config.secshell.zammad.enable {
    sops.secrets."zammad/secretKey".owner = "zammad";

    services = {
      zammad = {
        enable = true;
        port = config.secshell.zammad.ports.http;
        websocketPort = config.secshell.zammad.ports.websocket;
        secretKeyBaseFile = config.sops.secrets."zammad/secretKey".path;
      };

      nginx = {
        enable = true;
        virtualHosts.${toString config.secshell.zammad.domain} = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.secshell.zammad.ports.http}";
          };
          locations."/ws" = {
            proxyPass = "http://127.0.0.1:${toString config.secshell.zammad.ports.websocket}";
            proxyWebsockets = true;
          };

          serverName = toString config.secshell.zammad.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString config.secshell.zammad.domain;
          forceSSL = true;
        };
      };
    };

    security.acme.certs."${toString config.secshell.zammad.domain}" = { };
  };
}
