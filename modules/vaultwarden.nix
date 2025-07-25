{
  config,
  lib,
  ...
}:
{
  options.secshell.vaultwarden = {
    enable = lib.mkEnableOption "vaultwarden";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "vault.${toString config.networking.fqdn}";
      defaultText = "vault.\${toString config.networking.fqdn}";
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
    smtp = {
      hostname = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "mail.secshell.net";
        description = ''
          SMTP server hostname for outgoing email.
          Leave null to disable email functionality.
        '';
      };
      from = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "noreply@secshell.net";
        description = ''
          The email address shown as the sender in outgoing emails.

          Important: When this doesn't match the SMTP service account's email address,
          you must configure your mailserver to allow sending from this address (alias or sender rewriting)
        '';
      };
      security = lib.mkOption {
        type = lib.types.str;
        default = "starttls";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = ''
          SMTP server port. STARTTLS uses 587, TLS uses 465 by default.
        '';
      };
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
        default = "vaultwarden";
        description = ''
          Database user account with read/write privileges.
          For PostgreSQL, ensure the user has CREATEDB permission
          for initial setup if creating databases automatically.
        '';
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "vaultwarden";
        description = ''
          Name of the database to use.
          Will be created automatically if the user has permissions.
        '';
      };
    };
  };
  config = lib.mkIf config.secshell.vaultwarden.enable {
    sops = {
      secrets = {
        "vaultwarden/adminToken" = { };
        "vaultwarden/hibpApiKey" = { };
      }
      // (lib.optionalAttrs (!config.secshell.vaultwarden.useLocalDatabase) {
        "vaultwarden/databasePassword" = { };
      })
      // (lib.optionalAttrs
        (config.secshell.vaultwarden.smtp.hostname != null && config.secshell.vaultwarden.smtp.from != null)
        {
          "vaultwarden/smtpUsername" = { };
          "vaultwarden/smtpPassword" = { };
        }
      );

      templates."vaultwarden/env".content =
        let
          databaseUsername = config.secshell.vaultwarden.database.username;
          databasePassword = config.sops.placeholder."vaultwarden/databasePassword";
          databaseHostname = config.secshell.vaultwarden.database.hostname;
          databaseName = config.secshell.vaultwarden.database.name;
          databaseUri = "postgresql://${databaseUsername}:${databasePassword}@${databaseHostname}/${databaseName}";
        in
        ''
          ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/adminToken"}
          HIBP_API_KEY=${config.sops.placeholder."vaultwarden/hibpApiKey"}
          ${lib.optionalString (!config.secshell.vaultwarden.useLocalDatabase) "DATABASE_URL=${databaseUri}"}
          ${lib.optionalString (
            config.secshell.vaultwarden.smtp.hostname != null && config.secshell.vaultwarden.smtp.from != null
          ) "SMTP_USERNAME=${config.sops.placeholder."vaultwarden/smtpUsername"}"}
          ${lib.optionalString (
            config.secshell.vaultwarden.smtp.hostname != null && config.secshell.vaultwarden.smtp.from != null
          ) "SMTP_PASSWORD=${config.sops.placeholder."vaultwarden/smtpPassword"}"}
        '';
    };

    services.postgresql = lib.mkIf config.secshell.vaultwarden.useLocalDatabase {
      enable = true;
      ensureDatabases = [ "vaultwarden" ];
    };

    services.vaultwarden = {
      enable = true;
      environmentFile = config.sops.templates."vaultwarden/env".path;
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = config.secshell.vaultwarden.internal_port;

        DOMAIN = "https://${config.secshell.vaultwarden.domain}";

        DATABASE_URL = lib.mkIf config.secshell.vaultwarden.useLocalDatabase "postgresql:///vaultwarden?host=/run/postgresql";

        SIGNUPS_ALLOWED = false;
        INVITATIONS_ALLOWED = false;

        ORG_EVENTS_ENABLED = true;
        EVENTS_DAYS_RETAIN = 30;
      }
      // (lib.optionalAttrs
        (config.secshell.vaultwarden.smtp.hostname != null && config.secshell.vaultwarden.smtp.from != null)
        {
          SMTP_HOST = config.secshell.vaultwarden.smtp.hostname;
          SMTP_FROM = config.secshell.vaultwarden.smtp.from;
          SMTP_FROM_NAME = "Vaultwarden";
          SMTP_SECURITY = config.secshell.vaultwarden.smtp.security;
          SMTP_PORT = config.secshell.vaultwarden.smtp.port;
        }
      );
      dbBackend = "postgresql";
    };

    services.nginx = {
      enable = true;
      virtualHosts."${toString config.secshell.vaultwarden.domain}" = {
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${toString config.secshell.vaultwarden.internal_port}/";
            proxyWebsockets = true;
          };
        };
        serverName = toString config.secshell.vaultwarden.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.secshell.vaultwarden.domain;
        forceSSL = true;
      };
    };
    security.acme.certs."${toString config.secshell.vaultwarden.domain}" = { };
  };
}
