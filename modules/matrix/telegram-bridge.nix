{ config, lib, ... }:
{
  options.secshell.matrix.telegram = {
    enable = lib.mkEnableOption "mautrix-telegram";
    internal_port = lib.mkOption {
      type = lib.types.port;
      default = 29317;
      description = ''
        The port that is used internally to forward traffic from synapse to the bridge.
      '';
    };
    adminUsername = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = lib.mkIf (!config.secshell.matrix.telegram.enable) null;
      description = ''
        The username of the matrix user, who should have admin privileges of this bridge.
      '';
    };
  };
  config = lib.mkIf config.secshell.matrix.telegram.enable {
    sops = {
      secrets = {
        "matrix/telegram-bridge/as-token" = { };
        "matrix/telegram-bridge/hs-token" = { };
        "matrix/telegram-bridge/tg-api-id" = { };
        "matrix/telegram-bridge/tg-api-hash" = { };
      };
      templates."matrix/telegram-bridge/env".content = ''
        MAUTRIX_TELEGRAM_APPSERVICE_AS_TOKEN=${config.sops.placeholder."matrix/telegram-bridge/as-token"}
        MAUTRIX_TELEGRAM_APPSERVICE_HS_TOKEN=${config.sops.placeholder."matrix/telegram-bridge/hs-token"}
        MAUTRIX_TELEGRAM_TELEGRAM_API_ID=${config.sops.placeholder."matrix/telegram-bridge/tg-api-id"}
        MAUTRIX_TELEGRAM_TELEGRAM_API_HASH=${config.sops.placeholder."matrix/telegram-bridge/tg-api-hash"}
      '';
    };

    services = {
      postgresql = {
        ensureDatabases = [ "mautrix-telegram" ];
      };

      mautrix-telegram = {
        enable = true;
        environmentFile = config.sops.templates."matrix/telegram-bridge/env".path;
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
    users.groups.mautrix-telegram = { };
    systemd.services.mautrix-telegram.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "mautrix-telegram";
      Group = "mautrix-telegram";
    };
  };
}
