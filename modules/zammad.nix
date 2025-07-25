{
  config,
  lib,
  ...
}:
let
  cfg = config.secshell.zammad;
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    ;
in
{
  options.secshell.zammad = {
    enable = mkEnableOption "zammad";
    domain = mkOption {
      type = types.str;
      default = "support.${toString config.networking.fqdn}";
      defaultText = "support.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for this service.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    ports = {
      http = mkOption {
        type = types.port;
        default = 3000;
        description = ''
          The local port the service listens on.
        '';
      };
      websocket = mkOption {
        type = types.port;
        default = 6042;
        description = ''
          The local port the websocket listener of the service listens on.
        '';
      };
    };
  };
  config = mkIf cfg.enable {
    sops.secrets."zammad/secretKey".owner = "zammad";

    services = {
      zammad = {
        enable = true;
        port = cfg.ports.http;
        websocketPort = cfg.ports.websocket;
        secretKeyBaseFile = config.sops.secrets."zammad/secretKey".path;
      };

      nginx = {
        enable = true;
        virtualHosts.${toString cfg.domain} = {
          locations."/" = {
            proxyPass = "http://${config.services.zammad.host}:${toString cfg.ports.http}";
          };
          locations."/ws" = {
            proxyPass = "http://${config.services.zammad.host}:${toString cfg.ports.websocket}";
            proxyWebsockets = true;
          };

          serverName = toString cfg.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString cfg.domain;
          forceSSL = true;
        };
      };
    };

    security.acme.certs."${toString cfg.domain}" = { };
  };
}
