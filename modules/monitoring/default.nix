{ lib
, config
, ...
}: {
  imports = [
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
        default = [];
      };
      postgres = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      blackbox_http = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      blackbox_icmp = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      other = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };

    alertmanagerDefaultEmailReceiver = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
    };
  };

  config = lib.mkIf config.secshell.monitoring.enable {
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
          static_configs = [
            {
              targets = [
                "localhost:9090"
              ];
            }
          ];
        }
        {
          job_name = "node_exporter";
          static_configs = [
            {
              targets = config.secshell.monitoring.exporter.node;
            }
          ];
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
          static_configs = [
            {
              targets = config.secshell.monitoring.exporter.postgres;
            }
          ];
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
          static_configs = [
            {
              targets = config.secshell.monitoring.exporter.other;
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              regex = "([^:]+):\\d+";
              target_label = "instance";
            }
          ];
        }
        {
          job_name = "blackbox_exporter_http";
          metrics_path = "/probe";
          params = {
            module = [ "http_2xx" ];
          };
          static_configs = [
            {
              targets = config.secshell.monitoring.exporter.blackbox_http;
            }
          ];
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
          static_configs = [
            {
              targets = config.secshell.monitoring.exporter.blackbox_icmp;
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target__" ];
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
          static_configs = [
            {
              targets = [
                "localhost:9091"
              ];
            }
          ];
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
      rules = [
        ''
          ALERT JobDown
          IF up == 0
          FOR 5m
          LABELS {
            severity="critical"
          }
          ANNOTATIONS {
            summary = "{{$labels.alias}}: Node is down.",
            description = "{{$labels.alias}} has been down for more than 5 minutes."
          }

          ALERT HostOutOfMemory
          IF (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 10) * on(instance) group_left (nodename) node_uname_info{nodename=~".+"}
          FOR 2m
          LABELS {
            severity="warning"
          }
          ANNOTATIONS {
            summary = "Host out of memory (instance {{ $labels.instance }})",
            description = "Node memory is filling up (< 10% left)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
          }

          ALERT BlackboxProbeFailed
          IF probe_success == 0
          FOR 0m
          LABELS {
            severity="critical"
          }
          ANNOTATIONS {
            summary = "Blackbox probe failed (instance {{ $labels.instance }})",
            description = "Probe failed\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
          }

          ALERT BlackboxSslCertificateWillExpireSoon
          IF 0 <= round((last_over_time(probe_ssl_earliest_cert_expiry[10m]) - time()) / 86400, 0.1) < 30
          FOR 0m
          LABELS {
            severity="warning"
          }
          ANNOTATIONS {
            summary = "Blackbox SSL certificate will expire soon (instance {{ $labels.instance }})",
            description = "SSL certificate expires in less than 30 days\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
          }

          ALERT BlackboxSslCertificateWillExpireSoon
          IF 0 <= round((last_over_time(probe_ssl_earliest_cert_expiry[10m]) - time()) / 86400, 0.1) < 30
          FOR 0m
          LABELS {
            severity="warning"
          }
          ANNOTATIONS {
            summary = "Blackbox SSL certificate will expire soon (instance {{ $labels.instance }})",
            description = "SSL certificate expires in less than 30 days\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
          }

          ALERT HostOutOfDiskSpace
          IF ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes < 10 and ON (instance, device, mountpoint) node_filesystem_readonly == 0) * on(instance) group_left (nodename) node_uname_info{nodename=~".+"}
          FOR 2m
          LABELS {
            severity="warning"
          }
          ANNOTATIONS {
            summary = "Host out of disk space (instance {{ $labels.instance }})",
            description = "Disk is almost full (< 10% left)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
          }

          ALERT HostDiskWillFillIn24Hours
          IF ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes < 10 and ON (instance, device, mountpoint) predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs"}[1h], 24 * 3600) < 0 and ON (instance, device, mountpoint) node_filesystem_readonly == 0) * on(instance) group_left (nodename) node_uname_info{nodename=~".+"}
          FOR 2m
          LABELS {
            severity="warning"
          }
          ANNOTATIONS {
            summary = "Host disk will fill in 24 hours (instance {{ $labels.instance }})",
            description = "Filesystem is predicted to run out of space within the next 24 hours at current write rate\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
          }

          ALERT HostHighCpuLoad
          IF (sum by (instance) (avg by (mode, instance) (rate(node_cpu_seconds_total{mode!="idle"}[2m]))) > 0.8) * on(instance) group_left (nodename) node_uname_info{nodename=~".+"}
          FOR 7d
          LABELS {
            severity="warning"
          }
          ANNOTATIONS {
            summary = "Host high CPU load (instance {{ $labels.instance }})",
            description = "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
          }

          ALERT HostCpuHighIowait
          IF (avg by (instance) (rate(node_cpu_seconds_total{mode="iowait"}[5m])) * 100 > 10) * on(instance) group_left (nodename) node_uname_info{nodename=~".+"}
          LABELS {
            severity="warning"
          }
          ANNOTATIONS {
            summary = "Host CPU high iowait (instance {{ $labels.instance }})",
            description = "CPU iowait > 10%. A high iowait means that you are disk or network bound.\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
          }
        ''
      ];
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
      };
    };

    networking.firewall.allowedTCPPorts = [
      9090  # prometheus
      9091  # pushgateway
      9093  # alertmanager
    ];
  };
}
