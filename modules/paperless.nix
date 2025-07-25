{
  config,
  lib,
  ...
}:
{
  options.secshell.paperless = {
    enable = lib.mkEnableOption "paperless";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "paperless.${toString config.networking.fqdn}";
      defaultText = "paperless.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for this service.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    internal_port = lib.mkOption {
      type = lib.types.port;
      description = ''
        The local port the service listens on.
      '';
    };
    useLocalDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to use a local database instance for this service.
        When enabled (default), the service will deploy and manage
        its own postgres database. When disabled, you must configure external
        database connection parameters separately.
      '';
    };
    database = {
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Database server hostname. Not required if local database is being used.
        '';
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "paperless";
        description = ''
          Database user account with read/write privileges.
          For PostgreSQL, ensure the user has CREATEDB permission
          for initial setup if creating databases automatically.
        '';
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "paperless";
        description = ''
          Name of the database to use.
          Will be created automatically if the user has permissions.
        '';
      };
    };
    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "secshelladmin";
      description = ''
        The username of the initial account,
        which is being automaticly created with the password in sops.
      '';
    };
    enableTika = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether tika / gotenberg should be configured for ocr.";
    };
  };
  config = lib.mkIf config.secshell.paperless.enable {
    sops = lib.recursiveUpdate { secrets."paperless/password" = { }; } (
      lib.optionalAttrs (!config.secshell.paperless.useLocalDatabase) {
        secrets."paperless/databasePassword" = { };
        templates."paperless/env".content = "PAPERLESS_DBPASS=${
          config.sops.placeholder."paperless/databasePassword"
        }";
      }
    );

    services.postgresql = lib.mkIf config.secshell.paperless.useLocalDatabase {
      enable = true;
      ensureDatabases = [ "paperless" ];
    };

    services.paperless = {
      enable = true;
      address = "127.0.0.1";
      port = config.secshell.paperless.internal_port;
      configureTika = config.secshell.paperless.enableTika;
      settings = {
        PAPERLESS_OCR_LANGUAGE = "deu+eng";

        PAPERLESS_DBHOST = "/run/postgresql";

        PAPERLESS_CONSUMER_IGNORE_PATTERN = builtins.toJSON [
          ".DS_STORE/\*"
          "desktop.ini"
        ];

        PAPERLESS_URL = "https://${toString config.secshell.paperless.domain}";
        PAPERLESS_TIME_ZONE = "Europe/Berlin";

        PAPERLESS_ADMIN_USER = config.secshell.paperless.adminUsername;

        PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
      }
      // (lib.optionalAttrs (!config.secshell.paperless.useLocalDatabase) {
        # https://docs.paperless-ngx.com/configuration/#database
        PAPERLESS_DBHOST = config.secshell.paperless.database.hostname;
        PAPERLESS_DBUSER = config.secshell.paperless.database.username;
        PAPERLESS_DBNAME = config.secshell.paperless.database.name;
      });

      passwordFile = config.sops.secrets."paperless/password".path;
    };

    # systemd prevents access to network services by default
    systemd.services = lib.mkIf (!config.secshell.paperless.useLocalDatabase) {
      # TODO only when using remote database or everytime (because of unix sockets)
      "paperless-scheduler".serviceConfig.RestrictAddressFamilies = lib.mkForce [ ];
      "paperless-scheduler".serviceConfig.PrivateNetwork = lib.mkForce false;
      "paperless-consumer".serviceConfig.RestrictAddressFamilies = lib.mkForce [ ];
      "paperless-consumer".serviceConfig.PrivateNetwork = lib.mkForce false;

      # set database passwords
      "paperless-web".serviceConfig.EnvironmentFile = config.sops.templates."paperless/env".path;
      "paperless-task-queue".serviceConfig.EnvironmentFile = config.sops.templates."paperless/env".path;
      "paperless-consumer".serviceConfig.EnvironmentFile = config.sops.templates."paperless/env".path;
      "paperless-scheduler".serviceConfig.EnvironmentFile = config.sops.templates."paperless/env".path;
    };

    services.nginx = {
      enable = true;
      virtualHosts.${toString config.secshell.paperless.domain} = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.secshell.paperless.internal_port}";
          proxyWebsockets = true;
          extraConfig = ''
            client_max_body_size 1G;
          '';
        };
        serverName = toString config.secshell.paperless.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.secshell.paperless.domain;
        forceSSL = true;
      };
    };

    security.acme.certs."${toString config.secshell.paperless.domain}" = { };
  };
}
