{
  config,
  lib,
  ...
}:
let
  cfg = config.secshell.radicale;
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    ;
in
{
  options.secshell.radicale = {
    enable = mkEnableOption "radicale";
    domain = mkOption {
      type = types.str;
      default = "dav.${toString config.networking.fqdn}";
      defaultText = "dav.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for this service.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    internal_port = mkOption {
      type = types.port;
      description = ''
        The local port the service listens on.
      '';
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."radicale/users" = {
      owner = "radicale";
      group = "radicale";
    };

    services = {
      radicale = {
        enable = true;
        settings = {
          server.hosts = [ "[::1]:${toString cfg.internal_port}" ];
          auth = {
            type = "htpasswd";
            htpasswd_filename = config.sops.secrets."radicale/users".path;
            htpasswd_encryption = "bcrypt";
          };
        };
      };

      nginx = {
        enable = true;
        virtualHosts."${toString cfg.domain}" = {
          locations."/" = {
            proxyPass = "http://${builtins.head config.services.radicale.settings.server.hosts}/";
            extraConfig = ''
              proxy_set_header X-Script-Name /;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_pass_header Authorization;
            '';
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
