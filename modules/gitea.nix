{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.secshell.gitea = {
    enable = lib.mkEnableOption "gitea";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "git.${toString config.networking.fqdn}";
    };
    internal_port = lib.mkOption { type = lib.types.port; };
    useLocalDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    smtp = {
      hostname = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      from = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
      };
      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      noReplyAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = config.secshell.gitea.from;
      };
    };
    database = {
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "gitea";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "gitea";
      };
    };
    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 22;
    };
    requireSignInView = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    enableNotifyMail = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    allowOnlyExternalRegistrations = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    defaultKeepEmailPrivate = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
  config = lib.mkIf config.secshell.gitea.enable {
    sops.secrets = (
      {
        "gitea/databasePassword".owner = "gitea";
      }
      // lib.optionalAttrs (config.secshell.gitea.smtp.hostname != null) {
        "gitea/smtpPassword".owner = "gitea";
      }
    );

    services.postgresql = lib.mkIf config.secshell.gitea.useLocalDatabase {
      enable = true;
      ensureDatabases = [ "gitea" ];
    };

    services.gitea = {
      enable = true;
      database =
        {
          type = "postgres";
        }
        // (lib.optionalAttrs (config.secshell.gitea.useLocalDatabase) { host = "/run/postgresql"; })
        // (lib.optionalAttrs (!config.secshell.gitea.useLocalDatabase) {
          host = config.secshell.gitea.database.hostname;
          user = config.secshell.gitea.database.username;
          name = config.secshell.gitea.database.name;
          passwordFile = config.sops.secrets."gitea/databasePassword".path;
          createDatabase = false;
        });
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
          "ALLOW_ONLY_EXTERNAL_REGISTRATION" = config.secshell.gitea.allowOnlyExternalRegistrations;
          "DEFAULT_KEEP_EMAIL_PRIVATE" = config.secshell.gitea.defaultKeepEmailPrivate;
          "NO_REPLY_ADDRESS" = config.secshell.gitea.smtp.noReplyAddress;
        };
        mailer = {
          ENABLED = true;
          SMTP_ADDR = config.secshell.gitea.smtp.hostname;
          SMTP_PORT = config.secshell.gitea.smtp.port;
          FROM = config.secshell.gitea.smtp.from;
          USER = config.secshell.gitea.smtp.user;
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
      mailerPasswordFile = lib.mkIf (
        config.secshell.gitea.smtp.hostname != null
      ) config.sops.secrets."gitea/smtpPassword".path;
    };
    networking.firewall.allowedTCPPorts = [ config.secshell.gitea.sshPort ];

    services.nginx = {
      enable = true;
      virtualHosts."${toString config.secshell.gitea.domain}" = {
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${toString config.secshell.gitea.internal_port}/";
            proxyWebsockets = true;
          };
        };
        serverName = toString config.secshell.gitea.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.secshell.gitea.domain;
        forceSSL = true;
      };
    };
    security.acme.certs."${toString config.secshell.gitea.domain}" = { };
  };
}
