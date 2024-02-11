{ config
, lib
, ...
}: {
  options.secshell.matrix.telegram = {
    enable = lib.mkEnableOption "mautrix-telegram";
    internal_port = lib.mkOption {
      type = lib.types.port;
      default = 29317;
    };
    adminUsername = lib.mkOption {
      type = lib.types.str;
    };
  };
  config = lib.mkIf config.secshell.matrix.telegram.enable {
    sops.secrets = {
      "matrix/telegram-bridge/environment" = {};
      "matrix/telegram-bridge/registration" = {
        path = "/var/lib/mautrix-telegram/telegram-registration.yaml";
        owner = "mautrix-telegram";
        group = "matrix-synapse";
        mode = "440";
      };
    };

    services = {
      postgresql = {
        ensureDatabases = [ "mautrix-telegram" ];
      };

      mautrix-telegram = {
        enable = true;
        environmentFile = config.sops.secrets."matrix/telegram-bridge/environment".path;
        settings = {
          homeserver = {
            address = "https://${config.secshell.matrix.domain}/";
            domain = config.secshell.matrix.homeserver;
          };
          appservice = {
            bot_username = "tgbot";
            database = "postgresql:///mautrix-telegram?host=/run/postgresql";
            address = "http://127.0.0.1:${toString config.secshell.matrix.telegram.internal_port}";
            port = config.secshell.matrix.telegram.internal_port;
          };
          bridge = {
            permissions = {
              "*" = "relaybot";
              "@${config.secshell.matrix.whatsapp.adminUsername}:${config.secshell.matrix.homeserver}" = "admin";
            };
          };
        };
      };
    };
    users.users.mautrix-telegram = {
      isSystemUser = true;
      group = "mautrix-telegram";
    };
    users.groups.mautrix-telegram = {};
    systemd.services.mautrix-telegram.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "mautrix-telegram";
      Group = "mautrix-telegram";
    };
  };
}
