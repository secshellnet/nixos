{ config, lib, ... }:
{
  options.secshell.simple-upload = {
    enable = lib.mkEnableOption "simple-upload";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "upload.${toString config.networking.fqdn}";
      defaultText = "upload.\${toString config.networking.fqdn}";
    };
  };
  config = lib.mkIf config.secshell.simple-upload.enable {
    sops.secrets."simple-upload/basicAuth".owner = "nginx";

    # ensure upload directory exists
    systemd.tmpfiles.rules = [ "d /var/lib/uploads 750 nginx nginx" ];

    # systemd prevent write access to /var/lib/uploads by default by making it read only
    systemd.services.nginx.serviceConfig = {
      ReadWriteDirectories = "/var/lib/uploads";
    };

    services.nginx = {
      enable = true;
      virtualHosts."${toString config.secshell.simple-upload.domain}" = {
        basicAuthFile = config.sops.secrets."simple-upload/basicAuth".path;
        locations = {
          "/" = {
            index = baseNameOf ./simple-upload/upload.html;
            root = dirOf ./simple-upload/upload.html;
          };
          "/data/" = {
            alias = "/var/lib/uploads/";
            extraConfig = ''
              autoindex on;
            '';
          };
          "~ \"/upload/([^\\/]+)$\"" = {
            alias = "/var/lib/uploads/$1";
            extraConfig = ''
              dav_methods PUT;
              create_full_put_path on;
              dav_access group:r all:r;
              client_max_body_size 500M;
            '';
          };
        };
        serverName = toString config.secshell.simple-upload.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.secshell.simple-upload.domain;
        forceSSL = true;
      };
    };
    security.acme.certs."${toString config.secshell.simple-upload.domain}" = { };
  };
}
