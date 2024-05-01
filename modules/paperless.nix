{ config
, lib
, pkgs
, ...
}: {
  options.secshell.paperless = {
    enable = lib.mkEnableOption "paperless";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "paperless.${toString config.networking.fqdn}";
    };
    internal_port = lib.mkOption {
      type = lib.types.port;
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
        default = "paperless";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "paperless";
      };
    };
    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "secshelladmin";
    };
  };
  config = lib.mkIf config.secshell.paperless.enable {
    sops = lib.recursiveUpdate {
      secrets."paperless/password" = {};
    } (lib.optionalAttrs (! config.secshell.paperless.useLocalDatabase) {
      secrets."paperless/databasePassword" = {};
      templates."paperless/env".content = "PAPERLESS_DBPASS=${config.sops.placeholder."paperless/databasePassword"}";    
    });

    services.postgresql = lib.mkIf config.secshell.paperless.useLocalDatabase {
      enable = true;
      ensureDatabases = ["paperless"];
    };

    services.paperless = {
      enable = true;
      address = "127.0.0.1";
      port = config.secshell.paperless.internal_port;
      extraConfig = {
        PAPERLESS_OCR_LANGUAGE = "deu+eng";

        PAPERLESS_DBHOST = "/run/postgresql";

        PAPERLESS_CONSUMER_IGNORE_PATTERN = builtins.toJSON [ ".DS_STORE/\*" "desktop.ini" ];

        PAPERLESS_URL = "https://${toString config.secshell.paperless.domain}";
        PAPERLESS_TIME_ZONE = "Europe/Berlin";

        PAPERLESS_ADMIN_USER = config.secshell.paperless.adminUsername;

        PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
      } // (lib.optionalAttrs (! config.secshell.paperless.useLocalDatabase) {
        # https://docs.paperless-ngx.com/configuration/#database
        PAPERLESS_DBHOST = config.secshell.paperless.database.hostname;
        PAPERLESS_DBUSER = config.secshell.paperless.database.username;
        PAPERLESS_DBNAME = config.secshell.paperless.database.name;
      });

      passwordFile = config.sops.secrets."paperless/password".path;
    };

    # systemd prevents access to network services by default
    systemd.services = lib.mkIf (!config.secshell.paperless.useLocalDatabase) {  # TODO only when using remote database or everytime (because of unix sockets)
      "paperless-scheduler".serviceConfig.RestrictAddressFamilies = lib.mkForce [];
      "paperless-scheduler".serviceConfig.PrivateNetwork = lib.mkForce false;
      #"paperless-task-queue".serviceConfig.RestrictAddressFamilies = lib.mkForce [];  # TODO is this enough
      #"paperless-consumer".serviceConfig.PrivateNetwork = lib.mkForce false;
      #"paperless-consumer".serviceConfig.RestrictAddressFamilies = lib.mkForce [];
      #"paperless-web".serviceConfig.RestrictAddressFamilies = lib.mkForce [];
      
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

    security.acme.certs."${toString config.secshell.paperless.domain}" = {};
  };
}
