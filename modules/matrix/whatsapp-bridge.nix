{ config, lib, ... }:
{
  options.secshell.matrix.whatsapp = {
    enable = lib.mkEnableOption "mautrix-whatsapp";
    internal_port = lib.mkOption {
      type = lib.types.port;
      default = 29318;
      description = ''
        The port that is used internally to forward traffic from synapse to the bridge.
      '';
    };
    adminUsername = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = lib.mkIf (!config.secshell.matrix.whatsapp.enable) null;
      description = ''
        The username of the matrix user, who should have admin privileges of this bridge.
      '';
    };
  };
  config = lib.mkIf config.secshell.matrix.whatsapp.enable {
    sops = {
      secrets = {
        "matrix/whatsapp-bridge/as-token" = { };
        "matrix/whatsapp-bridge/hs-token" = { };
      };
      templates."matrix/whatsapp-bridge/env".content = ''
        MAUTRIX_WHATSAPP_APPSERVICE_AS_TOKEN=${config.sops.placeholder."matrix/whatsapp-bridge/as-token"}
        MAUTRIX_WHATSAPP_APPSERVICE_HS_TOKEN=${config.sops.placeholder."matrix/whatsapp-bridge/hs-token"}
      '';
    };

    services = {
      postgresql = {
        ensureDatabases = [ "mautrix-whatsapp" ];
      };

      mautrix-whatsapp = {
        enable = true;
        environmentFile = config.sops.templates."matrix/whatsapp-bridge/env".path;
        settings = {
          homeserver = {
            address = "https://${config.secshell.matrix.domain}/";
            domain = config.secshell.matrix.homeserver;
          };
          appservice = {
            bot.username = "wabot";
            database.type = "postgres";
            database.uri = "postgresql:///mautrix-whatsapp?host=/run/postgresql";
            address = "http://127.0.0.1:${toString config.secshell.matrix.whatsapp.internal_port}";
            port = config.secshell.matrix.whatsapp.internal_port;
          };
          bridge = {
            displayname_template = "{{or .FullName .PushName .Phone}} (WA)";
            permissions = {
              "*" = "relay";
              "@${config.secshell.matrix.whatsapp.adminUsername}:${config.secshell.matrix.homeserver}" = "admin";
            };
          };
        };
      };
    };
    users.users.mautrix-whatsapp = {
      isSystemUser = true;
      group = "mautrix-whatsapp";
    };
    users.groups.mautrix-whatsapp = { };
    systemd.services.mautrix-whatsapp.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "mautrix-whatsapp";
      Group = "mautrix-whatsapp";
    };
  };
}
