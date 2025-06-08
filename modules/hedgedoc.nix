{ config, lib, ... }:
let
  cfg = config.secshell.hedgedoc;
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
  options.secshell.hedgedoc = {
    enable = mkEnableOption "hedgedoc";
    domain = mkOption {
      type = types.str;
      default = "md.${toString config.networking.fqdn}";
      defaultText = "md.\${toString config.networking.fqdn}";
    };
    internal_port = mkOption { type = types.port; };
    useLocalDatabase = mkOption {
      type = types.bool;
      default = true;
    };
    database = {
      hostname = mkOption {
        type = types.str;
        default = "/run/postgresql";
      };
      username = mkOption {
        type = types.str;
        default = "hedgedoc";
      };
      name = mkOption {
        type = types.str;
        default = "hedgedoc";
      };
    };
    oidc = {
      domain = mkOption {
        type = types.str;
        default = "";
      };
      realm = mkOption {
        type = types.str;
        default = "main";
      };
      clientId = mkOption {
        type = types.str;
        default = cfg.domain;
        defaultText = "config.secshell.hedgedoc.domain";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # base
    {
      sops = {
        secrets."hedgedoc/sessionSecret" = { };
        templates."hedgedoc/environment".content = ''
          CMD_SESSION_SECRET=\"${config.sops.placeholder."hedgedoc/sessionSecret"}\"
        '';
      };

      services = {
        hedgedoc = {
          enable = true;
          environmentFile = config.sops.templates."hedgedoc/environment".path;
          settings = {
            domain = cfg.domain;
            host = "127.0.0.1";
            port = cfg.internal_port;
            protocolUseSSL = true;

            db = {
              dialect = "postgresql";
              host = cfg.database.hostname;
              username = cfg.database.username;
              database = cfg.database.name;
            };

            email = cfg.oidc.domain == "";
            allowEmailRegister = false;

            allowAnonymous = false;
            allowAnonymousEdits = true;
            allowFreeURL = true;
            requireFreeURLAuthentication = true;
            defaultPermission = "private";
          };
        };

        nginx = {
          enable = true;
          virtualHosts.${toString cfg.domain} = {
            locations."/" = {
              proxyPass = "http://${config.services.hedgedoc.settings.host}:${toString cfg.internal_port}";
              proxyWebsockets = true;
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

    # configure local database
    (mkIf cfg.useLocalDatabase {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "hedgedoc" ];
      };
    })

    # configure external database
    (mkIf (!cfg.useLocalDatabase) {
      sops = {
        secrets."hedgedoc/databasePassword" = { };
        templates."hedgedoc/environment".content = mkAfter ''
          CMD_DB_PASSWORD=\"${config.sops.placeholder."hedgedoc/databasePassword"}\"
        '';
      };
    })

    # configure oidc
    (mkIf (cfg.oidc.domain != "") {
      sops = {
        secrets."hedgedoc/oidcSecret" = { };
        templates."hedgedoc/environment".content = mkAfter ''
          CMD_OAUTH2_CLIENT_SECRET=\"${config.sops.placeholder."hedgedoc/oidcSecret"}\"
        '';
      };

      services.hedgedoc.settings.oauth2 = mkIf (cfg.oidc.domain != "") {
        userProfileURL = "https://${cfg.oidc.domain}/realms/${cfg.oidc.realm}/protocol/openid-connect/userinfo";
        userProfileUsernameAttr = "preferred_username";
        userProfileDisplayNameAttr = "name";
        userProfileEmailAttr = "email";
        tokenURL = "https://${cfg.oidc.domain}/realms/${cfg.oidc.realm}/protocol/openid-connect/token";
        authorizationURL = "https://${cfg.oidc.domain}/realms/${cfg.oidc.realm}/protocol/openid-connect/auth";
        clientID = cfg.oidc.clientId;
        clientSecret = ""; # defined in secrets, but needs to exists for login button to show
        providerName = "Keycloak";
        scope = "openid email profile";
      };
    })
  ]);
}
