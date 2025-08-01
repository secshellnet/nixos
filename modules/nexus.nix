{
  config,
  lib,
  ...
}:
{
  options.secshell.nexus = {
    enable = lib.mkEnableOption "nexus";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "nexus.${toString config.networking.fqdn}";
      defaultText = "nexus.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for this service.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    internal_port = lib.mkOption {
      type = lib.types.port;
      description = ''
        The local port the service listens on.
      '';
    };
  };
  config = lib.mkIf config.secshell.nexus.enable {
    services = {
      nexus = {
        enable = true;
        listenPort = config.secshell.nexus.internal_port;
      };

      nginx = {
        enable = true;
        virtualHosts."${toString config.secshell.nexus.domain}" = {
          locations = {
            "/".proxyPass = "http://127.0.0.1:${toString config.secshell.nexus.internal_port}";
          };
          serverName = toString config.secshell.nexus.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString config.secshell.nexus.domain;
          forceSSL = true;
        };
      };
    };
    security.acme.certs."${toString config.secshell.nexus.domain}" = { };
  };
}
