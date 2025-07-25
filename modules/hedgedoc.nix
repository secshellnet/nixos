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
    database = {
      hostname = mkOption {
        type = types.str;
        default = "/run/postgresql";
        description = ''
          Database server hostname. Not required if local database is being used.
        '';
      };
      username = mkOption {
        type = types.str;
        default = "hedgedoc";
        description = ''
          Database user account with read/write privileges.
          For PostgreSQL, ensure the user has CREATEDB permission
          for initial setup if creating databases automatically.
        '';
      };
      name = mkOption {
        type = types.str;
        default = "hedgedoc";
        description = ''
          Name of the database to use.
          Will be created automatically if the user has permissions.
        '';
      };
    };
    oidc = {
      domain = mkOption {
        type = types.str;
        default = "";
        description = ''
          The open id connect server used for authentication.
          Leave null to disable oidc authentication.
        '';
      };
      realm = mkOption {
        type = types.str;
        default = "main";
        description = ''
          The realm to use for the open id connect authentication.
        '';
      };
      clientId = mkOption {
        type = types.str;
        default = cfg.domain;
        defaultText = "config.secshell.hedgedoc.domain";
        description = ''
          The client id for the open id connect authentication.
        '';
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
