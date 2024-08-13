# Monitoring Module

## Loki

[Loki](https://grafana.com/oss/loki/) is a log aggregator.

Loki is not enabled by default, to enable set `secshell.monitoring.loki.enable = true` (this requires `secshell.monitoring.enable = true` as well!).

As logging is highly domain and scale specific, we only provide a minimal setup for loki.
Please [configure](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/monitoring/loki.nix) `services.loki` yourself!
[Grafana hosts a reference](https://grafana.com/docs/loki/latest/configure/#configuration-file-reference) for the `services.loki.configuration` object.

Loki is exposed only using the `config.secshell.monitoring.domains.loki` nginx virtual host. We highly recommend to add authentication mechanisms using nginx (e.g., basic auth, `services.nginx.virtualHosts.${toString config.secshell.monitoring.domains.loki}.basicAuthFile = ...`).

As all monitoring nginx virtual hosts, it is only available over TLS. The certificates for this are automatically managed using ACME.

### Example configuration

```nix
 secshell = {
    monitoring = {
      enable = true;

      loki.enable = true;

      # ...
    };
    # ...
 };

 services.loki = {

    dataDir = "/var/lib/loki"; # default

    # https://grafana.com/docs/loki/latest/configure/#configuration-file-reference
    configuration = {
      target = "all"; # run all components of loki in one container

      auth_enabled = false; # we will configure auth in nginx

      # set up loki's own logging
      server = {
        log_level = "info";
        log_request_headers = true;
      };

      common = {
        path_prefix = "/var/lib/loki";
        storage = {
          filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
        };
        replication_factor = 1;
        ring = {
          kvstore = {
            store = "inmemory";
          };
        };
      };

      query_range = {
        results_cache = {
          cache = {
            embedded_cache = {
              enabled = true;
              max_size_mb = 100;
            };
          };
        };
      };

      schema_config = {
        configs = [
          {
            from = "2020-10-24";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };

      compactor = {
        retention_enabled = true;
        compaction_interval = "10m"; # How often the compactor spins up
        retention_delete_delay = "1h"; # Deleted chunks are fully removed after a grace period
        delete_request_store = "filesystem";
      };

      limits_config = {
        retention_period = "744h"; # 1 month
      };
    };
  };

  # use sops secrets for basic auth
  sops.secrets.lokiBasicPassword = {};
  sops.templates.lokiBasicAuth = {
    # allow nginx user to read the sops secret
    owner = config.services.nginx.user;
    group = config.services.nginx.group;
    content = ''loki:${config.sops.placeholder.lokiBasicPassword}''; # basic user: loki, basic passwd: in yaml
  };

  services.nginx.virtualHosts."loki.${toString config.networking.fqdn}" = {
    basicAuthFile = config.sops.templates.lokiBasicAuth.path;
  };
```
