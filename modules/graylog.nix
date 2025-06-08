{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.secshell.graylog;
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    ;
in
{
  options.secshell.graylog = {
    enable = mkEnableOption "graylog";
    domain = mkOption {
      type = types.str;
      default = "graylog.${toString config.networking.fqdn}";
      defaultText = "graylog.\${toString config.networking.fqdn}";
    };
    internal_port = mkOption { type = types.port; };
  };
  config = mkIf cfg.enable {
    sops.secrets."graylog/rootPassword".owner = "graylog";
    services = {
      mongodb.enable = true;
      elasticsearch = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      graylog = {
        enable = true;
        rootUsername = "secshelladmin";
        rootPasswordSha2 = ""; # will be set to correct value by preStart command
        passwordSecret = config.sops.secrets."graylog/rootPassword".path;
        elasticsearchHosts = [ "http://${config.services.elasticsearch.listenAddress}:9200" ];
        nodeIdFile = "/var/lib/graylog/node-id";
        extraConfig = ''
          http_bind_address = 127.0.0.1:${toString cfg.internal_port}
          http_publish_uri = https://${toString cfg.domain}
          content_packs_loader_enabled = false
        '';
      };
    };

    # ensure graylog config file can be written by pre start job which runs as graylog
    systemd.tmpfiles.rules = [ "f /etc/graylog.conf 640 graylog graylog" ];

    # add password hash from secrets to configuration
    systemd.services.graylog.preStart = ''
      hash=$(cat ${config.services.graylog.passwordSecret} | ${pkgs.perl}/bin/shasum -a 256 | ${pkgs.coreutils-full}/bin/cut -d " " -f1)
      ${pkgs.gnused}/bin/sed "s/root_password_sha2.*/root_password_sha2 = $hash/g" $GRAYLOG_CONF > /etc/graylog.conf
      export GRAYLOG_CONF="/etc/graylog.conf"
    '';

    services.nginx = {
      enable = true;
      virtualHosts.${toString cfg.domain} = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.internal_port}";
          proxyWebsockets = true;
        };
        serverName = toString cfg.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString cfg.domain;
        forceSSL = true;
      };
    };

    security.acme.certs."${toString cfg.domain}" = { };
  };
}
