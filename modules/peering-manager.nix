{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.secshell.peering-manager;
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    mkMerge
    ;
in
{
  options.secshell.peering-manager = {
    enable = mkEnableOption "peering-manager";
    domain = mkOption {
      type = types.str;
      default = "peering-manager.${toString config.networking.fqdn}";
      defaultText = "peering-manager.\${toString config.networking.fqdn}";
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
        defaultText = "config.secshell.peering-manager.domain";
        description = ''
          The client id for the open id connect authentication.
        '';
      };
    };
  };
  config = mkIf cfg.enable (mkMerge [
    # base
    {
      sops.secrets."peering-manager/secretKey".owner = "peering-manager";

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
          port = cfg.internal_port;
          listenAddress = "127.0.0.1";

          settings = {
            LOGIN_REQUIRED = true;
            TIME_ZONE = "Europe/Berlin";
            ALLOWED_HOSTS = [ (toString cfg.domain) ];
          };
        };
        nginx = {
          enable = true;
          virtualHosts."${toString cfg.domain}" = {
            locations = {
              "/".proxyPass = "http://127.0.0.1:${toString cfg.internal_port}";
              "/static/".alias = "${pkgs.peering-manager}/opt/peering-manager/static/";
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

    # external database
    {
      # the nixpkgs module configures a local postgres instance, which we a simply not using
      # disabling postgres in this postgres module might cause trouble with other modules that should use a local postgres instance
      # TODO
      #services.peering-manager.settings.DATABASE = {
      #  NAME = "peering-manager";
      #  USER = "peering-manager";
      #  HOST = "/run/postgresql";
      #};
    }

    # oidc
    # TODO requires adjustments for https://github.com/NixOS/nixpkgs/pull/382862
    (mkIf (cfg.oidc.domain != "") {
      sops = {
        secrets = (
          lib.optionalAttrs (cfg.oidc.domain != "") {
            "peering-manager/oidcSecret".owner = "peering-manager";
          }
        );

        templates."peering-manager/oidc-config" = {
          content = ''
            # CLIENT_ID and SECRET are required to authenticate against the provider
            OIDC_RP_CLIENT_ID = "${cfg.oidc.clientId}"
            OIDC_RP_CLIENT_SECRET = "${config.sops.placeholder."peering-manager/oidcSecret"}"

            # The following two may be required depending on your provider,
            # check the configuration endpoint for JWKS information
            OIDC_RP_SIGN_ALGO = "RS256"
            OIDC_OP_JWKS_ENDPOINT = "https://${cfg.oidc.domain}/realms/${cfg.oidc.realm}/protocol/openid-connect/certs"

            # Refer to the configuration endpoint of your provider
            OIDC_OP_AUTHORIZATION_ENDPOINT = "https://${cfg.oidc.domain}/realms/${cfg.oidc.realm}/protocol/openid-connect/auth"
            OIDC_OP_TOKEN_ENDPOINT = "https://${cfg.oidc.domain}/realms/${cfg.oidc.realm}/protocol/openid-connect/token"
            OIDC_OP_USER_ENDPOINT = "https://${cfg.oidc.domain}/realms/${cfg.oidc.realm}/protocol/openid-connect/userinfo"

            # Set these to the base path of your Peering Manager installation
            LOGIN_REDIRECT_URL = "https://${cfg.domain}"
            LOGOUT_REDIRECT_URL = "https://${cfg.domain}"

            # If this is True, new users will be created if not yet existing.
            OIDC_CREATE_USER = True
          '';
          owner = "peering-manager";
        };
      };

      services.peering-manager = {
        enableOidc = true;
        oidcConfigPath = config.sops.templates."peering-manager/oidc-config".path;
      };
    })
  ]);
}
