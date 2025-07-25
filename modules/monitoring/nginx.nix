{ config, lib, ... }:
{
  options.secshell.monitoring.domains = {
    prometheus = lib.mkOption {
      type = lib.types.str;
      default = "prom.${toString config.networking.fqdn}";
      defaultText = "prom.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for prometheus.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    alertmanager = lib.mkOption {
      type = lib.types.str;
      default = "alerts.${toString config.networking.fqdn}";
      defaultText = "alerts.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for the prometheus alertmanager.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    pushgateway = lib.mkOption {
      type = lib.types.str;
      default = "pushgateway.${toString config.networking.fqdn}";
      defaultText = "pushgateway.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for the prometheus pushgateway.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    grafana = lib.mkOption {
      type = lib.types.str;
      default = "grafana.${toString config.networking.fqdn}";
      defaultText = "grafana.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for grafana.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    loki = lib.mkOption {
      type = lib.types.str;
      default = "loki.${toString config.networking.fqdn}";
      defaultText = "loki.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for loki.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
  };
  config = lib.mkIf config.secshell.monitoring.enable {
    services.nginx = {
      enable = true;
      virtualHosts."${config.secshell.monitoring.domains.prometheus}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.secshell.monitoring.prometheus.internal_port}/";
        };
        serverName = config.secshell.monitoring.domains.prometheus;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.networking.fqdn;
        forceSSL = true;
      };
      virtualHosts."${config.secshell.monitoring.domains.alertmanager}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.secshell.monitoring.alertmanager.internal_port}/";
        };
        serverName = config.secshell.monitoring.domains.alertmanager;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.networking.fqdn;
        forceSSL = true;
      };
      virtualHosts."${config.secshell.monitoring.domains.pushgateway}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.secshell.monitoring.pushgateway.internal_port}/";
        };
        serverName = config.secshell.monitoring.domains.pushgateway;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.networking.fqdn;
        forceSSL = true;
      };
    };

    security.acme.certs."${toString config.networking.fqdn}" = {
      extraDomainNames = [
        config.secshell.monitoring.domains.prometheus
        config.secshell.monitoring.domains.alertmanager
        config.secshell.monitoring.domains.pushgateway
      ]
      ++ (lib.optionals config.services.grafana.enable [ config.secshell.monitoring.domains.grafana ])
      ++ (lib.optionals config.services.loki.enable [ config.secshell.monitoring.domains.loki ]);
    };
  };
}
