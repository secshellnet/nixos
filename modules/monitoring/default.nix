{ lib, config, ... }:
{
  imports = [
    ./loki.nix
    ./grafana.nix
    ./nginx.nix
  ];

  options.secshell.monitoring = {
    enable = lib.mkEnableOption "monitoring";
    prometheus.internal_port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
    };
    alertmanager.internal_port = lib.mkOption {
      type = lib.types.port;
      default = 9093;
    };
    pushgateway.internal_port = lib.mkOption {
      type = lib.types.port;
      default = 9091;
    };
    node_exporter.internal_port = lib.mkOption {
      type = lib.types.port;
      default = 9100;
    };
    blackbox_exporter.internal_port = lib.mkOption {
      type = lib.types.port;
      default = 9115;
    };

    exporter = {
      node = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      postgres = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      blackbox_http = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      blackbox_icmp = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      other = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      wireguard = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      frr = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      pve = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };

    alertmanagerDefaultEmailReceiver = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
    };
  };

  config = lib.mkIf config.secshell.monitoring.enable {
    sops.templates."monitoring/pve-exporter.conf" = {};

    services.prometheus = {
      enable = true;
      port = config.secshell.monitoring.prometheus.internal_port;
      globalConfig = {
        scrape_interval = "30s";
        evaluation_interval = "30s";
        external_labels = {
          cluster = toString config.networking.fqdn;
          replica = "0";
        };
      };
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [ { targets = [ "localhost:9090" ]; } ];
        }
        {
          job_name = "node_exporter";
          static_configs = [ { targets = config.secshell.monitoring.exporter.node; } ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              regex = "([^:]+):\\d+";
              target_label = "instance";
            }
          ];
        }
        {
          job_name = "postgres_exporter";
          static_configs = [ { targets = config.secshell.monitoring.exporter.postgres; } ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              regex = "([^:]+):\\d+";
              target_label = "instance";
            }
          ];
        }
        {
          job_name = "other_exporter";
          static_configs = [ { targets = config.secshell.monitoring.exporter.other; } ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              regex = "([^:]+):\\d+";
              target_label = "instance";
            }
          ];
        }
        {
          job_name = "wireguard_exporter";
          static_configs = [ { targets = config.secshell.monitoring.exporter.wireguard; } ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              regex = "([^:]+):\\d+";
              target_label = "instance";
            }
          ];
        }
        {
          job_name = "frr_exporter";
          static_configs = [ { targets = config.secshell.monitoring.exporter.frr; } ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              regex = "([^:]+):\\d+";
              target_label = "instance";
            }
          ];
        }
        {
          job_name = "pve_exporter";
          static_configs = [ { targets = config.secshell.monitoring.exporter.pve; } ];
          metrics_path = "/pve";
          params = {
            module = [ "default" ];
            cluster = [ "1" ];
            node = [ "1" ];
          };
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9221";
            }
          ];
        }
        {
          job_name = "blackbox_exporter_http";
          metrics_path = "/probe";
          params = {
            module = [ "http_2xx" ];
          };
          static_configs = [ { targets = config.secshell.monitoring.exporter.blackbox_http; } ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "${toString config.networking.fqdn}:${toString config.services.prometheus.exporters.blackbox.port}";
            }
          ];
        }
        {
          job_name = "blackbox_exporter_icmp";
          metrics_path = "/probe";
          params = {
            module = [ "icmp" ];
          };
          static_configs = [ { targets = config.secshell.monitoring.exporter.blackbox_icmp; } ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "${toString config.networking.fqdn}:${toString config.services.prometheus.exporters.blackbox.port}";
            }
          ];
        }
        {
          job_name = "blackbox_exporter";
          static_configs = [
            {
              targets = [
                "${toString config.networking.fqdn}:${toString config.services.prometheus.exporters.blackbox.port}"
              ];
            }
          ];
        }
        {
          job_name = "pushgateway";
          honor_labels = true;
          static_configs = [ { targets = [ "localhost:9091" ]; } ];
        }
      ];
      alertmanager = {
        enable = true;
        port = config.secshell.monitoring.alertmanager.internal_port;
        configuration = {
          route = {
            group_wait = "10s";
            group_interval = "30s";
            repeat_interval = "1d";
            receiver = "default";

            routes = [
              {
                receiver = "default";
                match_re = {
                  severity = "critical";
                };
                continue = true;
              }
            ];
          };
          receivers = [
            {
              name = "default";
              email_configs = config.secshell.monitoring.alertmanagerDefaultEmailReceiver;
            }
          ];
        };
      };
      pushgateway.enable = true;
      pushgateway.web.listen-address = ":${toString config.secshell.monitoring.pushgateway.internal_port}";
      ruleFiles = [ ./rules.yml ];
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          listenAddress = "127.0.0.2";
          port = config.secshell.monitoring.node_exporter.internal_port;
        };
        blackbox = {
          enable = true;
          configFile = ./blackbox.yml;
          listenAddress = "127.0.0.2";
          port = config.secshell.monitoring.blackbox_exporter.internal_port;
        };
        pve = {
          enable = config.secshell.monitoring.exporter.pve != [];
          configFile = config.sops.templates."monitoring/pve-exporter.conf".path;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      9090 # prometheus
      9091 # pushgateway
      9093 # alertmanager
    ];
  };
}
