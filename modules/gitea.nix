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
    };
    internal_port = mkOption { type = types.port; };
    useLocalDatabase = mkOption {
      type = types.bool;
      default = true;
    };
    smtp = {
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      from = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      port = mkOption {
        type = types.port;
        default = 587;
      };
      user = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      noReplyAddress = mkOption {
        type = types.nullOr types.str;
        default = config.secshell.gitea.from;
        defaultText = "config.secshell.gitea.from";
      };
    };
    database = {
      hostname = mkOption {
        type = types.str;
        default = "";
      };
      username = mkOption {
        type = types.str;
        default = "gitea";
      };
      name = mkOption {
        type = types.str;
        default = "gitea";
      };
    };
    appName = mkOption {
      type = types.str;
      default = "Secure Shell Networks: Gitea";
    };
    sshPort = mkOption {
      type = types.port;
      default = 22;
    };
    requireSignInView = mkOption {
      type = types.bool;
      default = true;
    };
    enableNotifyMail = mkOption {
      type = types.bool;
      default = true;
    };
    allowOnlyExternalRegistrations = mkOption {
      type = types.bool;
      default = true;
    };
    defaultKeepEmailPrivate = mkOption {
      type = types.bool;
      default = true;
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
