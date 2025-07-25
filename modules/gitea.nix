{
  config,
  lib,
  ...
}:
let
  cfg = config.secshell.gitea;
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    mkMerge
    ;
in
{
  options.secshell.gitea = {
    enable = mkEnableOption "gitea";
    domain = mkOption {
      type = types.str;
      default = "git.${toString config.networking.fqdn}";
      defaultText = "git.\${toString config.networking.fqdn}";
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
      port = mkOption {
        type = types.port;
        default = 587;
        example = 465;
        description = ''
          SMTP server port. STARTTLS uses 587, TLS uses 465 by default.
        '';
      };
      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          SMTP authentication username.
          Typically the full email address of the service account which is being used to send mails..
        '';
      };
      noReplyAddress = mkOption {
        type = types.nullOr types.str;
        default = config.secshell.gitea.from;
        defaultText = "config.secshell.gitea.from";
        example = "support@secshell.net";
        description = ''
          "From" address for automated/non-reply emails.
        '';
      };
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
        default = "gitea";
        description = ''
          Database user account with read/write privileges.
          For PostgreSQL, ensure the user has CREATEDB permission
          for initial setup if creating databases automatically.
        '';
      };
      name = mkOption {
        type = types.str;
        default = "gitea";
        description = ''
          Name of the database to use.
          Will be created automatically if the user has permissions.
        '';
      };
    };
    appName = mkOption {
      type = types.str;
      default = "Secure Shell Networks: Gitea";
      description = ''
        The application name of the gitea instance.
      '';
    };
    sshPort = mkOption {
      type = types.port;
      default = 22;
    };
    requireSignInView = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable this to force users to log in to view any page or to use API.
        It could be set to "expensive" to block anonymous users accessing some
        pages which consume a lot of resources, for example: block anonymous AI
        crawlers from accessing repo code pages. The "expensive" mode is experimental
        and subject to change.
      '';
    };
    enableNotifyMail = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable this to send e-mail to watchers of a repository when something happens,
        like creating issues. Requires Mailer to be enabled.
      '';
    };
    allowOnlyExternalRegistrations = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Set to true to force registration only using third-party services.
      '';
    };
    defaultKeepEmailPrivate = mkOption {
      type = types.bool;
      default = true;
      description = "By default set users to keep their email address private.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # base
    {
      services = {
        gitea = {
          enable = true;
          inherit (cfg) appName;
          settings = {
            server = {
              HTTP_ADDR = "127.0.0.1";
              HTTP_PORT = config.secshell.gitea.internal_port;
              DOMAIN = config.secshell.gitea.domain;
              ROOT_URL = "https://${config.secshell.gitea.domain}";
              SSH_PORT = config.secshell.gitea.sshPort;
            };
            service = {
              "REQUIRE_SIGNIN_VIEW" = config.secshell.gitea.requireSignInView;
              "ENABLE_NOTIFY_MAIL" = config.secshell.gitea.enableNotifyMail;
              "ALLOW_ONLY_EXTERNAL_REGISTRATION" = cfg.allowOnlyExternalRegistrations;
              "DEFAULT_KEEP_EMAIL_PRIVATE" = cfg.defaultKeepEmailPrivate;
            };
            openid = {
              ENABLE_OPENID_SIGNIN = false;
              ENABLE_OPENID_SIGNUP = false;
            };
            oauth2_client = {
              ENABLE_AUTO_REGISTRATION = true;
            };
            ui = {
              SHOW_USER_EMAIL = false;
              DEFAULT_SHOW_FULL_NAME = false;
              EXPLORE_PAGING_NUM = 100;
              ISSUE_PAGING_NUM = 100;
            };
          };
        };
        nginx = {
          enable = true;
          virtualHosts."${toString cfg.domain}" = {
            locations = {
              "/" = {
                proxyPass = "http://${config.services.gitea.settings.server.HTTP_ADDR}:${toString cfg.internal_port}/";
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

      networking.firewall.allowedTCPPorts = [ cfg.sshPort ];

      security.acme.certs."${toString cfg.domain}" = { };
    }

    # configure local database
    (mkIf cfg.useLocalDatabase {
      services = {
        gitea.database = {
          type = "postgres";
          host = "/run/postgresql";
        };
        postgresql = {
          enable = true;
          ensureDatabases = [ "gitea" ];
        };
      };
    })

    # configure external database
    (mkIf (!cfg.useLocalDatabase) {
      sops.secrets."gitea/databasePassword".owner = "gitea";

      services.gitea.database = {
        type = "postgres";
        host = cfg.database.hostname;
        user = cfg.database.username;
        name = cfg.database.name;
        passwordFile = config.sops.secrets."gitea/databasePassword".path;
        createDatabase = false;
      };
    })

    # configure smtp
    (mkIf (cfg.smtp.hostname != null) {
      sops.secrets."gitea/smtpPassword".owner = "gitea";

      services.gitea = {
        settings = {
          mailer = {
            ENABLED = true;
            SMTP_ADDR = cfg.smtp.hostname;
            SMTP_PORT = cfg.smtp.port;
            FROM = cfg.smtp.from;
            USER = cfg.smtp.user;
          };
          service."NO_REPLY_ADDRESS" = cfg.smtp.noReplyAddress;
        };
        mailerPasswordFile = config.sops.secrets."gitea/smtpPassword".path;
      };
    })
  ]);
}
