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
    mkPackageOption
    mkOption
    mkMerge
    ;
in
{
  options.secshell.peering-manager = {
    enable = mkEnableOption "peering-manager";
    package = mkPackageOption pkgs "peering-manager" { } // {
      apply = mkIf (cfg.oidc.endpoint != "") 
        pkg: pkg.overrideAttrs (old: {
          installPhase = old.installPhase + ''
            ln -s ${./pipeline.py} $out/opt/peering_manager/peering_manager/peering_manager/secshell_pipeline.py
          '';
        })
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
      endpoint = mkOption {
        type = types.str;
        default = "";
        example = "https://auth.secshell.net/application/o/peering-manager/";
        description = ''
          The open id connect server used for authentication.
          Leave null to disable oidc authentication.
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
    # TODO add oidc pipeline as in netbox
    # TODO restruction options as in netbox (oidc.endpoint instead of domain)
    (mkIf (cfg.oidc.endpoint != "") {
      sops = {
        secrets."peering-manager/oidcSecret".owner = "peering-manager";

        templates."peering-manager/oidc-config" = {
          content = ''
            PM_OIDC_SECRET=${config.sops.placeholder."peering-manager/oidcSecret"}
          '';
          owner = "peering-manager";
        };
      };

      # see https://peering-manager.readthedocs.io/en/stable/administration/authentication/oidc/
      services.peering-manager = {
        environmentFile = config.sops.templates."peering-manager/oidc-config".path;
        settings = {
          REMOTE_AUTH_ENABLED = true;
          REMOTE_AUTH_BACKEND = "social_core.backends.open_id_connect.OpenIdConnectAuth";
          SOCIAL_AUTH_BACKEND_ATTRS = {"oidc": ("Authentik", "fa-fw fa-brands fa-openid")};
          SOCIAL_AUTH_OIDC_ENDPOINT = cfg.oidc.endpoint;
          SOCIAL_AUTH_OIDC_KEY = "${cfg.oidc.clientId}";
          SOCIAL_AUTH_OIDC_SECRET = "$PM_OIDC_SECRET";
          SOCIAL_AUTH_OIDC_SCOPE = ["openid", "profile", "email", "roles"];
          LOGOUT_REDIRECT_URL = "${cfg.oidc.endpoint}end-session/";
        };
        extraConfig = ''
          SOCIAL_AUTH_PIPELINE = (
            ###################
            # Default pipelines
            ###################
            # Get the information we can about the user and return it in a simple
            # format to create the user instance later. In some cases the details are
            # already part of the auth response from the provider, but sometimes this
            # could hit a provider API.
            "social_core.pipeline.social_auth.social_details",
            # Get the social uid from whichever service we're authing thru. The uid is
            # the unique identifier of the given user in the provider.
            "social_core.pipeline.social_auth.social_uid",
            # Verifies that the current auth process is valid within the current
            # project, this is where emails and domains whitelists are applied (if
            # defined).
            "social_core.pipeline.social_auth.auth_allowed",
            # Checks if the current social-account is already associated in the site.
            "social_core.pipeline.social_auth.social_user",
            # Make up a username for this person, appends a random string at the end if
            # there's any collision.
            "social_core.pipeline.user.get_username",
            # Send a validation email to the user to verify its email address.
            # Disabled by default.
            # 'social_core.pipeline.mail.mail_validation',
            # Associates the current social details with another user account with
            # a similar email address. Disabled by default.
            # 'social_core.pipeline.social_auth.associate_by_email',
            # Create a user account if we haven't found one yet.
            "social_core.pipeline.user.create_user",
            # Create the record that associates the social account with the user.
            "social_core.pipeline.social_auth.associate_user",
            # Populate the extra_data field in the social record with the values
            # specified by settings (and the default ones like access_token, etc).
            "social_core.pipeline.social_auth.load_extra_data",
            # Update the user record with any changed info from the auth service.
            "social_core.pipeline.user.user_details",
            ###################
            # Custom pipelines
            ###################
            # Set authentik Groups
            "peering_manager.secshell_pipeline.add_groups",
            "peering_manager.secshell_pipeline.remove_groups",
            # Set Roles
            "peering_manager.secshell_pipeline.set_roles",
          )
        '';
      };
    })
  ]);
}
