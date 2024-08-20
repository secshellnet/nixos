{ config, lib, ... }:
{
  options.secshell.monitoring.loki = {
    enable = lib.mkEnableOption "loki";
    internal_port = lib.mkOption {
      type = lib.types.port;
      default = 3100;
    };
  };
  config = lib.mkIf config.secshell.monitoring.loki.enable {
    services.loki = {
      enable = true;
      configuration.analytics.reporting_enabled = false; # prevent loki from talking home
      configuration.common.instance_addr = "127.0.0.1"; # only allow local traffic (will be exposed over nginx)
      configuration.server.http_listen_port = config.secshell.monitoring.loki.internal_port;
      # rest to be configured by user
    };

    services.nginx = {
      enable = true;
      virtualHosts."${toString config.secshell.monitoring.domains.loki}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.secshell.monitoring.loki.internal_port}/";
        };
        serverName = toString config.secshell.monitoring.domains.loki;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.networking.fqdn;
        forceSSL = true;
      };
    };
  };
}
