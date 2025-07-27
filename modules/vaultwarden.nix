{
  config,
  lib,
  ...
}:
let
  cfg = config.secshell.vaultwarden;
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    mkMerge
    mkAfter
    ;
in
{
  options.secshell.vaultwarden = {
    enable = mkEnableOption "vaultwarden";
    domain = mkOption {
      type = types.str;
      default = "vault.${toString config.networking.fqdn}";
      defaultText = "vault.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for this service.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    internal_port = mkOption {
      type = types.port;
      description = ''
        The local port the service listens on.
      '';
    };
    smtp = {
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "mail.secshell.net";
        description = ''
          SMTP server hostname for outgoing email.
          Leave null to disable email functionality.
        '';
      };
      from = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "noreply@secshell.net";
        description = ''
          The email address shown as the sender in outgoing emails.

          Important: When this doesn't match the SMTP service account's email address,
          you must configure your mailserver to allow sending from this address (alias or sender rewriting)
        '';
      };
      security = mkOption {
        type = types.str;
        default = "starttls";
      };
      port = mkOption {
        type = types.port;
        default = 587;
        description = ''
          SMTP server port. STARTTLS uses 587, TLS uses 465 by default.
        '';
      };
    };
    useLocalDatabase = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to use a local database instance for this service.
        When enabled (default), the service will deploy and manage
        its own postgres database. When disabled, you must configure external
        database connection parameters separately.
      '';
    };
    database = {
      hostname = mkOption {
        type = types.str;
        default = "";
        description = ''
          Database server hostname. Not required if local database is being used.
        '';
      };
      username = mkOption {
        type = types.str;
        default = "vaultwarden";
        description = ''
          Database user account with read/write privileges.
          For PostgreSQL, ensure the user has CREATEDB permission
          for initial setup if creating databases automatically.
        '';
      };
      name = mkOption {
        type = types.str;
        default = "vaultwarden";
        description = ''
          Name of the database to use.
          Will be created automatically if the user has permissions.
        '';
      };
    };
  };
  config = mkIf cfg.enable (mkMerge [
    # base
    {
      sops = {
        secrets = {
          "vaultwarden/adminToken" = { };
          "vaultwarden/hibpApiKey" = { };
        };
        templates."vaultwarden/env".content = ''
          ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/adminToken"}
          HIBP_API_KEY=${config.sops.placeholder."vaultwarden/hibpApiKey"}
        '';
      };

      services = {
        vaultwarden = {
          enable = true;
          environmentFile = config.sops.templates."vaultwarden/env".path;
          config = {
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = cfg.internal_port;

            DOMAIN = "https://${cfg.domain}";

            SIGNUPS_ALLOWED = false;
            INVITATIONS_ALLOWED = false;

            ORG_EVENTS_ENABLED = true;
            EVENTS_DAYS_RETAIN = 30;
          };
          dbBackend = "postgresql";
        };

        nginx = {
          enable = true;
          virtualHosts."${toString cfg.domain}" = {
            locations = {
              "/" = {
                proxyPass = "http://127.0.0.1:${toString cfg.internal_port}/";
                proxyWebsockets = true;
              };
            };
            serverName = toString cfg.domain;

            # use ACME DNS-01 challenge
            useACMEHost = toString cfg.domain;
            forceSSL = true;
          };
        };
      };
      security.acme.certs."${toString cfg.domain}" = { };
    }

    # local database
    (mkIf cfg.useLocalDatabase {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "vaultwarden" ];
      };

      services.vaultwarden.config = {
        DATABASE_URL = "postgresql:///vaultwarden?host=/run/postgresql";
      };
    })

    # external database
    (mkIf (!cfg.useLocalDatabase) {
      sops = {
        secrets."vaultwarden/databasePassword" = { };
        templates."vaultwarden/env".content =
          let
            dbUser = cfg.database.username;
            dbPass = config.sops.placeholder."vaultwarden/databasePassword";
            dbHost = cfg.database.hostname;
            dbName = cfg.database.name;
          in
          mkAfter ''
            DATABASE_URL=postgresql://${dbUser}:${dbPass}@${dbHost}/${dbName}
          '';
      };
    })

    # smtp
    (mkIf (cfg.smtp.hostname != null && cfg.smtp.from != null) {
      sops = {
        secrets = {
          "vaultwarden/smtpUsername" = { };
          "vaultwarden/smtpPassword" = { };
        };
        templates."vaultwarden/env".content = mkAfter ''
          SMTP_USERNAME=${config.sops.placeholder."vaultwarden/smtpUsername"}
          SMTP_PASSWORD=${config.sops.placeholder."vaultwarden/smtpPassword"}
        '';
      };

      services.vaultwarden.config = {
        SMTP_HOST = cfg.smtp.hostname;
        SMTP_FROM = cfg.smtp.from;
        SMTP_FROM_NAME = "Vaultwarden";
        SMTP_SECURITY = cfg.smtp.security;
        SMTP_PORT = cfg.smtp.port;
      };
    })
  ]);
}
