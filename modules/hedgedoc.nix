{ config
, lib
, ...
}: {
  options.secshell.hedgedoc = {
    enable = lib.mkEnableOption "hedgedoc";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "md.${toString config.networking.fqdn}";
    };
    internal_port = lib.mkOption {
      type = lib.types.port;
    };
    useLocalDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    database = {
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "/run/postgresql";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "hedgedoc";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "hedgedoc";
      };
    };
    oidc = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      realm = lib.mkOption {
        type = lib.types.str;
        default = "main";
      };
      clientId = lib.mkOption {
        type = lib.types.str;
        default = config.secshell.hedgedoc.domain;
      };
    };
  };
  config = lib.mkIf config.secshell.hedgedoc.enable {
    sops = {
      secrets = {
        "hedgedoc/sessionSecret" = {};
      } // (lib.optionalAttrs (! config.secshell.hedgedoc.useLocalDatabase) {
        "hedgedoc/databasePassword" = {};
      }) // (lib.optionalAttrs (config.secshell.hedgedoc.oidc.domain != "") {
        "hedgedoc/oidcSecret" = {};
      });

      templates."hedgedoc/environment".content = ''
        CMD_DB_PASSWORD=\"${config.sops.placeholder."hedgedoc/sessionSecret"}\"
        ${lib.optionalString (! config.secshell.hedgedoc.useLocalDatabase) "CMD_DB_PASSWORD=\"${config.sops.placeholder."hedgedoc/databasePassword"}\""}
        ${lib.optionalString (config.secshell.hedgedoc.oidc.domain != "") "CMD_OAUTH2_CLIENT_SECRET=\"${config.sops.placeholder."hedgedoc/oidcSecret"}\""}
      '';
    };

    services.postgresql = lib.mkIf config.secshell.hedgedoc.useLocalDatabase  {
      enable = true;
      ensureDatabases = [ "hedgedoc" ];
    };

    services.hedgedoc = {
      enable = true;
      environmentFile = config.sops.templates."hedgedoc/environment".path;
      settings = {
        domain = config.secshell.hedgedoc.domain;
        host = "127.0.0.1";
        port = config.secshell.hedgedoc.internal_port;
        protocolUseSSL = true;

        db = {
          dialect = "postgresql";
          host = config.secshell.hedgedoc.database.hostname;
          username = config.secshell.hedgedoc.database.username;
          database = config.secshell.hedgedoc.database.name;
        };

        email = config.secshell.hedgedoc.oidc.domain == "";
        allowEmailRegister = false;

        oauth2 = lib.mkIf (config.secshell.hedgedoc.oidc.domain != "") {
          userProfileURL = "https://${config.secshell.hedgedoc.oidc.domain}/realms/${config.secshell.hedgedoc.oidc.realm}/protocol/openid-connect/userinfo";
          userProfileUsernameAttr = "preferred_username";
          userProfileDisplayNameAttr = "name";
          userProfileEmailAttr = "email";
          tokenURL = "https://${config.secshell.hedgedoc.oidc.domain}/realms/${config.secshell.hedgedoc.oidc.realm}/protocol/openid-connect/token";
          authorizationURL = "https://${config.secshell.hedgedoc.oidc.domain}/realms/${config.secshell.hedgedoc.oidc.realm}/protocol/openid-connect/auth";
          clientID = config.secshell.hedgedoc.oidc.clientId;
          clientSecret = "";  # defined in secrets, but needs to exists for login button to show
          providerName = "Keycloak";
          scope = "openid email profile";
        };

        allowAnonymous = false;
        allowAnonymousEdits = true;
        allowFreeURL = true;
        requireFreeURLAuthentication = true;
        defaultPermission = "private";
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${toString config.secshell.hedgedoc.domain} = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.secshell.hedgedoc.internal_port}";
          proxyWebsockets = true;
        };
        serverName = toString config.secshell.hedgedoc.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.secshell.hedgedoc.domain;
        forceSSL = true;
      };
    };

    security.acme.certs."${toString config.secshell.hedgedoc.domain}" = {};
  };
}
