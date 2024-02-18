{ config
, lib
, ...
}: {
  options.secshell.monitoring.grafana = {
    internal_port = lib.mkOption {
      type = lib.types.port;
    };
    oidc = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      realm = lib.mkOption {
        type = lib.types.str;
        default = "main";
      };
      clientId = lib.mkOption {
        type = lib.types.str;
        default = config.secshell.monitoring.domains.grafana;
      };
    };
    useLocalDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    database = {
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "grafana";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "grafana";
      };
    };
  };
  config = lib.mkIf config.secshell.monitoring.enable {
    sops.secrets = {} // (lib.optionalAttrs (config.secshell.monitoring.grafana.oidc.domain != "") {
      "monitoring/grafana/oidcSecret".owner = "grafana";
    }) // (lib.optionalAttrs (! config.secshell.monitoring.grafana.useLocalDatabase) {
      "monitoring/grafana/databasePassword".owner = "grafana";
    });

    services.postgresql = lib.mkIf (config.secshell.monitoring.grafana.useLocalDatabase) {
      enable = true;
      ensureDatabases = [ "grafana" ];
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          domain = config.secshell.monitoring.domains.grafana;
          http_port = config.secshell.monitoring.grafana.internal_port;
          root_url = "https://%(domain)s/";
        };
        "auth.generic_oauth" = lib.mkIf (config.secshell.monitoring.grafana.oidc.domain != "") {
          enabled = true;
          name = "Keycloak";
          allow_sign_up = true;
          client_id = toString config.secshell.monitoring.grafana.oidc.clientId;
          client_secret = "$__file{${config.sops.secrets."monitoring/grafana/oidcSecret".path}}";
          scopes = "email profile roles openid";
          email_attribute_path = "email";
          login_attribute_path = "preferred_username";
          name_attribute_path = "full_name";
          auth_url = "https://${config.secshell.monitoring.grafana.oidc.domain}/realms/${config.secshell.monitoring.grafana.oidc.realm}/protocol/openid-connect/auth";
          token_url = "https://${config.secshell.monitoring.grafana.oidc.domain}/realms/${config.secshell.monitoring.grafana.oidc.realm}/protocol/openid-connect/token";
          api_url = "https://${config.secshell.monitoring.grafana.oidc.domain}/realms/${config.secshell.monitoring.grafana.oidc.realm}/protocol/openid-connect/userinfo";
        };
        database = {
          type = "postgres";
        } // (lib.optionalAttrs (config.secshell.monitoring.grafana.useLocalDatabase) {
          host = "/run/postgresql";
          user = "grafana";
        }) // (lib.optionalAttrs (!config.secshell.monitoring.grafana.useLocalDatabase) {
          host = config.secshell.monitoring.grafana.database.hostname;
          user = config.secshell.monitoring.grafana.database.username;
          name = config.secshell.monitoring.grafana.database.name;
          password = "$__file{${config.sops.secrets."monitoring/grafana/databasePassword".path}}";
        });
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:${toString config.services.prometheus.port}";
            isDefault = true;
          }
        ];
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."${toString config.services.grafana.settings.server.domain}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}/";
          proxyWebsockets = true;
        };
        serverName = toString config.services.grafana.settings.server.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.networking.fqdn;
        forceSSL = true;
      };
    };
  };
}
