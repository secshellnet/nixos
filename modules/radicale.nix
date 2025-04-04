{
  config,
  lib,
  ...
}:
{
  options.secshell.radicale = {
    enable = lib.mkEnableOption "radicale";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "dav.${toString config.networking.fqdn}";
      defaultText = "dav.\${toString config.networking.fqdn}";
    };
    internal_port = lib.mkOption { type = lib.types.port; };
  };

  config = lib.mkIf config.secshell.radicale.enable {
    sops.secrets."radicale/users" = {
      owner = "radicale";
      group = "radicale";
    };

    services.radicale = {
      enable = true;
      settings = {
        server = {
          hosts = [
            "[::1]:${toString config.secshell.radicale.internal_port}"
          ];
        };
        auth = {
          type = "htpasswd";
          htpasswd_filename = config.sops.secrets."radicale/users".path;
          htpasswd_encryption = "bcrypt";
        };
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."${toString config.secshell.radicale.domain}" = {
        locations = {
          "/" = {
            proxyPass = "http://[::1]:${toString config.secshell.radicale.internal_port}/";
            extraConfig = ''
              proxy_set_header X-Script-Name /;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_pass_header Authorization;
            '';
          };
        };
        serverName = toString config.secshell.radicale.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.secshell.radicale.domain;
        forceSSL = true;
      };
    };
    security.acme.certs."${toString config.secshell.radicale.domain}" = { };
  };
}
