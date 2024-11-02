{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.secshell.peering-manager = {
    enable = lib.mkEnableOption "peering-manager";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "peering-manager.${toString config.networking.fqdn}";
      defaultText = "peering-manager.\${toString config.networking.fqdn}";
    };
    internal_port = lib.mkOption { type = lib.types.port; };
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
        default = config.secshell.peering-manager.domain;
        defaultText = "config.secshell.peering-manager.domain";
      };
    };
  };
  config = lib.mkIf config.secshell.peering-manager.enable {
    sops = {
      secrets =
        {
          "peering-manager/secretKey".owner = "peering-manager";
        }
        // (lib.optionalAttrs (config.secshell.peering-manager.oidc.domain != "") {
          "peering-manager/oidcSecret".owner = "peering-manager";
        });

      templates."peering-manager/oidc-config".content = ''
        # CLIENT_ID and SECRET are required to authenticate against the provider
        OIDC_RP_CLIENT_ID = "${config.secshell.peering-manager.oidc.clientId}"
        OIDC_RP_CLIENT_SECRET = "${config.sops.placeholder."peering-manager/oidcSecret"}"

        # The following two may be required depending on your provider,
        # check the configuration endpoint for JWKS information
        OIDC_RP_SIGN_ALGO = "RS256"
        OIDC_OP_JWKS_ENDPOINT = "https://${config.secshell.peering-manager.oidc.domain}/realms/${config.secshell.peering-manager.oidc.realm}/protocol/openid-connect/certs"

        # Refer to the configuration endpoint of your provider
        OIDC_OP_AUTHORIZATION_ENDPOINT = "https://${config.secshell.peering-manager.oidc.domain}/realms/${config.secshell.peering-manager.oidc.realm}/protocol/openid-connect/auth"
        OIDC_OP_TOKEN_ENDPOINT = "https://${config.secshell.peering-manager.oidc.domain}/realms/${config.secshell.peering-manager.oidc.realm}/protocol/openid-connect/token"
        OIDC_OP_USER_ENDPOINT = "https://${config.secshell.peering-manager.oidc.domain}/realms/${config.secshell.peering-manager.oidc.realm}/protocol/openid-connect/userinfo"

        # Set these to the base path of your Peering Manager installation
        LOGIN_REDIRECT_URL = "https://${config.secshell.peering-manager.domain}"
        LOGOUT_REDIRECT_URL = "https://${config.secshell.peering-manager.domain}"

        # If this is True, new users will be created if not yet existing.
        OIDC_CREATE_USER = True
      '';
      templates."peering-manager/oidc-config".owner = "peering-manager";
    };

    services = {
      postgresql = {
        enable = true;
        ensureDatabases = [ "peering-manager" ];
      };
    };

    services = {
      peering-manager = {
        enable = true;
        secretKeyFile = config.sops.secrets."peering-manager/secretKey".path;
        port = config.secshell.peering-manager.internal_port;
        listenAddress = "127.0.0.1";
        enableOidc = config.secshell.peering-manager.oidc.domain != "";
        oidcConfigPath = lib.mkIf (
          config.secshell.peering-manager.oidc.domain != ""
        ) config.sops.templates."peering-manager/oidc-config".path;

        settings = {
          LOGIN_REQUIRED = true;
          TIME_ZONE = "Europe/Berlin";
          ALLOWED_HOSTS = [ (toString config.secshell.peering-manager.domain) ];
        };
      };
      nginx = {
        enable = true;
        virtualHosts."${toString config.secshell.peering-manager.domain}" = {
          locations = {
            "/".proxyPass = "http://127.0.0.1:${toString config.secshell.peering-manager.internal_port}";
            "/static/".alias = "${pkgs.peering-manager}/opt/peering-manager/static/";
          };
          serverName = toString config.secshell.peering-manager.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString config.secshell.peering-manager.domain;
          forceSSL = true;
        };
      };
    };
    security.acme.certs."${toString config.secshell.peering-manager.domain}" = { };
  };
}
