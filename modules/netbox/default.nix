{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
let
  cfg = config.secshell.netbox;
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    mkMerge
    ;
  mkDisableOption =
    name:
    mkEnableOption name
    // {
      default = true;
      example = false;
    };
in
{
  # Note for initial installation / database initialization: systemd timeout is way to small to finish the whole setup.
  # Run the deployment (or netbox systemd job) multiple times, until it works (arround 5 times required)

  options.secshell.netbox = {
    enable = mkEnableOption "netbox";
    package = lib.mkPackageOption pkgs-unstable "netbox" { } // {
      apply =
        pkg:
        if cfg.oidc.endpoint != "" then
          pkg.overrideAttrs (old: {
            installPhase = old.installPhase + ''
              ln -s ${./pipeline.py} $out/opt/netbox/netbox/netbox/secshell_pipeline.py
            '';
          })
        else
          pkg;
      description = ''
        The netbox package to use.
        If oidc is configured the secshell oidc pipeline for social auth
        will be automaticlly added to the package.
      '';
    };
    domain = mkOption {
      type = types.str;
      default = "netbox.${toString config.networking.fqdn}";
      defaultText = "netbox.\${toString config.networking.fqdn}";
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
        description = ''
          The open id connect server used for authentication.
          Leave null to disable oidc authentication.
        '';
      };
      clientId = mkOption {
        type = types.str;
        default = cfg.domain;
        defaultText = "config.secshell.netbox.domain";
        description = ''
          The client id for the open id connect authentication.
        '';
      };
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
        default = "";
        description = ''
          Database server hostname. Not required if local database is being used.
        '';
      };
      username = mkOption {
        type = types.str;
        default = "netbox";
        description = ''
          Database user account with read/write privileges.
          For PostgreSQL, ensure the user has CREATEDB permission
          for initial setup if creating databases automatically.
        '';
      };
      name = mkOption {
        type = types.str;
        default = "netbox";
        description = ''
          Name of the database to use.
          Will be created automatically if the user has permissions.
        '';
      };
    };
    plugin = {
      bgp = mkEnableOption "netbox bgp plugin";
      documents = mkEnableOption "netbox documents plugin";
      floorplan = mkEnableOption "netbox floorplan plugin";
      qrcode = mkEnableOption "netbox qrcode plugin";
      topologyViews = mkEnableOption "netbox topology views plugin";
      proxbox = mkEnableOption "netbox proxbox plugin";
      contract = mkEnableOption "netbox contract plugin";
      interface-synchronization = mkEnableOption "netbox interface-synchronization plugin";
      dns = mkEnableOption "netbox dns plugin";
      napalm = {
        enable = mkEnableOption "netbox napalm plugin";
        username = mkOption {
          type = types.str;
          default = "napalm";
          description = ''
            The username used for NAPALM authentication.
          '';
        };
        passwordFile = mkOption {
          type = types.path;
          description = ''
            File to a password used for NAPALM authentication.
          '';
        };
        ssl = mkDisableOption "ssl/tls for napalm connections";
      };
      reorder-rack = mkEnableOption "netbox reorder-rack plugin";
      prometheus-sd = mkEnableOption "netbox prometheus-sd plugin";
      kea = mkEnableOption "netbox kea plugin";
      attachments = mkEnableOption "netbox attachments plugin";
      contextmenus = mkEnableOption "netbox contextmenus plugin";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # base
    {
      sops.secrets."netbox/secretKey".owner = "netbox";

      services = {
        netbox = {
          enable = true;
          package = cfg.package;
          secretKeyFile = config.sops.secrets."netbox/secretKey".path;
          port = cfg.internal_port;
          listenAddress = "127.0.0.1";
          settings = {
            LOGIN_REQUIRED = true;
            TIME_ZONE = "Europe/Berlin";
            METRICS_ENABLED = true;
          };
        };
        nginx = {
          enable = true;
          virtualHosts."${toString cfg.domain}" = {
            locations = {
              "/".proxyPass = "http://127.0.0.1:${toString cfg.internal_port}";
              "/static/".alias = "${config.services.netbox.dataDir}/static/";
            };
            serverName = toString cfg.domain;

            # use ACME DNS-01 challenge
            useACMEHost = toString cfg.domain;
            forceSSL = true;
          };
        };
      };
      security.acme.certs."${toString cfg.domain}" = { };

      # adjust permissions to netbox static directory (so nginx user can read/browse these files)
      environment.systemPackages = with pkgs; [ acl ];
      systemd.services.netboxSetAcls = {
        script = ''
          # Set ACLs recursively for all files and directories under the NetBox data directory
          ${pkgs.acl}/bin/setfacl -m 'u:${config.services.nginx.user}:rx' ${config.services.netbox.dataDir}
          find ${config.services.netbox.dataDir}/static -type  d -exec ${pkgs.acl}/bin/setfacl -m 'u:${config.services.nginx.user}:rx' {} +   # world readeable
          find ${config.services.netbox.dataDir}/static -type f -exec ${pkgs.acl}/bin/setfacl -m 'u:${config.services.nginx.user}:r' {} +    # world readeable
        '';
        wantedBy = [ "multi-user.target" ];
      };
    }

    # plugins
    {
      services.netbox = {
        settings.PLUGINS = [
          (mkIf cfg.plugin.bgp "netbox_bgp")
          (mkIf cfg.plugin.documents "netbox_documents")
          (mkIf cfg.plugin.floorplan "netbox_floorplan")
          (mkIf cfg.plugin.qrcode "netbox_qrcode")
          (mkIf cfg.plugin.topologyViews "netbox_topology_views")
          #(mkIf cfg.plugin.proxbox "netbox_proxbox")
          (mkIf cfg.plugin.contract "netbox_contract")
          (mkIf cfg.plugin.interface-synchronization "netbox_interface_synchronization")
          (mkIf cfg.plugin.dns "netbox_dns")
          (mkIf cfg.plugin.napalm.enable "netbox_napalm_plugin")
          (mkIf cfg.plugin.reorder-rack "netbox_reorder_rack")
          (mkIf cfg.plugin.prometheus-sd "netbox_prometheus_sd")
          #(mkIf cfg.plugin.kea "netbox_kea")
          (mkIf cfg.plugin.attachments "netbox_attachments")
          (mkIf cfg.plugin.contextmenus "netbox_contextmenus")
        ];
        extraConfig = mkIf cfg.plugin.napalm.enable ''
          PLUGINS_CONFIG = {}
          PLUGINS_CONFIG["netbox_napalm_plugin"] = {}
          PLUGINS_CONFIG["netbox_napalm_plugin"]["NAPALM_USERNAME"] = "${cfg.plugin.napalm.username}"
          with open("${cfg.plugin.napalm.passwordFile}", "r") as file:
            PLUGINS_CONFIG["netbox_napalm_plugin"]["NAPALM_PASSWORD"] = file.readline()
          PLUGINS_CONFIG["netbox_napalm_plugin"]["NAPALM_ARGS"] = { "netbox_default_ssl_params": ${
            if cfg.plugin.napalm.ssl then "True" else "False"
          } }
        '';
        plugins =
          ps:
          let
            plugins = ps.callPackage ./plugins { };
          in
          [
            #(mkIf cfg.plugin.bgp ps.netbox-bgp)
            (mkIf cfg.plugin.bgp (
              ps.netbox-bgp.overridePythonAttrs (previous: {
                version = "0.16.0";
                src = previous.src.override {
                  tag = "v0.16.0";
                  hash = "sha256-pm6Xn34kPlGMzQAsiwrfTprPZtw7edsyr3PpRtJWnNE=";
                };
              })
            ))

            (mkIf cfg.plugin.documents (
              ps.netbox-documents.overridePythonAttrs (previous: {
                # https://github.com/NixOS/nixpkgs/pull/413944
                version = "0.7.3";
                src = previous.src.override {
                  tag = "v0.7.3";
                  hash = "sha256-lEbD+NuLyHXnXjGBdceE8RYhmoKEccRB4rKuxknjZL4=";
                };
                dependencies = [
                  (ps.drf-extra-fields.overridePythonAttrs (_previous: {
                    disabledTests = [
                      "test_create"
                      "test_create_with_base64_prefix"
                      "test_create_with_webp_image"
                      "test_remove_with_empty_string"
                      "test_read_source_with_context"
                    ];
                  }))
                ];
              })
            ))
            (mkIf cfg.plugin.floorplan (
              # https://github.com/NixOS/nixpkgs/pull/413224
              ps.netbox-floorplan-plugin.overridePythonAttrs (previous: {
                version = "0.7.0";
                src = previous.src.override {
                  tag = "0.7.0";
                  hash = "sha256-ecwPdcVuXU6OIVbafYGaY6+pbBHxhh1AlNmDBlUk1Ss=";
                };
              })
            ))
            (mkIf cfg.plugin.qrcode (
              # https://github.com/NixOS/nixpkgs/pull/411383
              ps.netbox-qrcode.overridePythonAttrs (previous: {
                version = "0.0.18";
                src = previous.src.override {
                  tag = "v0.0.18";
                  hash = "sha256-8PPab0sByr03zoSI2d+BpxeTnLHmbN+4c+s99x+yNvA=";
                };
              })
            ))
            (mkIf cfg.plugin.topologyViews (
              ps.netbox-topology-views.overridePythonAttrs (previous: {
                # https://github.com/NixOS/nixpkgs/pull/412588
                version = "4.3.0";
                src = previous.src.override {
                  tag = "v4.3.0";
                  hash = "sha256-K8hG2M8uWPk9+7u21z+hmedOovievkMNpn3p7I4+6t4=";
                };
              })
            ))
            #(mkIf cfg.plugin.proxbox plugins.netbox-proxbox)
            (mkIf cfg.plugin.contract ps.netbox-contract)
            (mkIf cfg.plugin.interface-synchronization (
              # https://github.com/NixOS/nixpkgs/pull/413560
              ps.netbox-interface-synchronization.overridePythonAttrs (previous: {
                version = "4.1.7";
                src = previous.src.override {
                  tag = "4.1.7";
                  hash = "sha256-02fdfE1BwpWsh21M0oP65kMAbFxDxYHsAEWA64rUl18=";
                };
              })
            ))
            (mkIf cfg.plugin.dns (
              ps.netbox-dns.overridePythonAttrs (previous: {
                # https://github.com/NixOS/nixpkgs/pull/404982
                version = "1.3.4";
                src = previous.src.override {
                  tag = "1.3.4";
                  hash = "sha256-Tk+Kzcve7jtJ8UyKdNUoNzct8AxOkZ84g/eg/vX1FEc=";
                };
              })
            ))
            # upstream of napalm-plugin doesn't support netbox 4.3 yet
            (mkIf cfg.plugin.napalm.enable (
              ps.netbox-napalm-plugin.overridePythonAttrs (previous: {
                dependencies = previous.dependencies ++ [
                  (ps.napalm-ros.overridePythonAttrs (_previous: {
                    disabled = false;
                  }))
                ];
              })
            ))
            (mkIf cfg.plugin.reorder-rack ps.netbox-reorder-rack)
            (mkIf cfg.plugin.prometheus-sd ps.netbox-plugin-prometheus-sd)
            #(mkIf cfg.plugin.kea plugins.netbox-kea)
            (mkIf cfg.plugin.attachments (
              ps.netbox-attachments.overridePythonAttrs (previous: {
                # https://github.com/NixOS/nixpkgs/pull/408776
                version = "8.0.4";
                src = previous.src.override {
                  tag = "8.0.4";
                  hash = "sha256-wVTI0FAj6RaEaE6FhvHq4ophnCspobqL2SnTYVynlxs=";
                };
              })
            ))
            (mkIf cfg.plugin.contextmenus plugins.netbox-contextmenus)
          ];
      };
    }

    # local database
    (mkIf cfg.useLocalDatabase {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "netbox" ];
      };
    })

    # external database
    (mkIf (!cfg.useLocalDatabase) {
      sops.secrets."netbox/databasePassword".owner = "netbox";

      # see https://docs.netbox.dev/en/stable/configuration/required-parameters/#database
      services.netbox.extraConfig = ''
        DATABASE = {
          'ENGINE': 'django.db.backends.postgresql',
          'NAME': '${cfg.database.name}',
          'USER': '${cfg.database.username}',
          'HOST': '${cfg.database.hostname}',
          'CONN_MAX_AGE': 300,
        }
        with open("${config.sops.secrets."netbox/databasePassword".path}", "r") as file:
          DATABASE['PASSWORD'] = file.readline()
      '';
    })

    # oidc
    (mkIf (cfg.oidc.endpoint != "") {
      sops.secrets."netbox/socialAuthSecret".owner = "netbox";

      services.netbox = {
        settings = {
          # https://stackoverflow.com/questions/53550321/keycloak-gatekeeper-aud-claim-and-client-id-do-not-match
          REMOTE_AUTH_ENABLED = true;
          REMOTE_AUTH_AUTO_CREATE_USER = true;
          REMOTE_AUTH_GROUP_SYNC_ENABLED = true;
          SOCIAL_AUTH_JSONFIELD_ENABLED = true;
          SOCIAL_AUTH_VERIFY_SSL = true;
          #SOCIAL_AUTH_OIDC_SCOPE = ["groups" "roles"];
          REMOTE_AUTH_BACKEND = "social_core.backends.open_id_connect.OpenIdConnectAuth";

          #REMOTE_AUTH_GROUP_SEPARATOR=",";
          REMOTE_AUTH_SUPERUSER_GROUPS = [ "superuser" ];
          REMOTE_AUTH_STAFF_GROUPS = [ "staff" ];
          REMOTE_AUTH_DEFAULT_GROUPS = [ "staff" ];
          SOCIAL_AUTH_OIDC_OIDC_ENDPOINT = cfg.oidc.endpoint;
          SOCIAL_AUTH_OIDC_KEY = cfg.oidc.clientId;
          LOGOUT_REDIRECT_URL = "${cfg.oidc.endpoint}end-session/";
        };
        extraConfig = ''
          with open("${config.sops.secrets."netbox/socialAuthSecret".path}", "r") as file:
            SOCIAL_AUTH_OIDC_SECRET = file.readline()

          SOCIAL_AUTH_PIPELINE = (
            ###################
            # Default pipelines
            ###################

            # Get the information we can about the user and return it in a simple
            # format to create the user instance later. In some cases the details are
            # already part of the auth response from the provider, but sometimes this
            # could hit a provider API.
            'social_core.pipeline.social_auth.social_details',

            # Get the social uid from whichever service we're authing thru. The uid is
            # the unique identifier of the given user in the provider.
            'social_core.pipeline.social_auth.social_uid',

            # Verifies that the current auth process is valid within the current
            # project, this is where emails and domains whitelists are applied (if
            # defined).
            'social_core.pipeline.social_auth.auth_allowed',

            # Checks if the current social-account is already associated in the site.
            'social_core.pipeline.social_auth.social_user',

            # Make up a username for this person, appends a random string at the end if
            # there's any collision.
            'social_core.pipeline.user.get_username',

            # Send a validation email to the user to verify its email address.
            # Disabled by default.
            # 'social_core.pipeline.mail.mail_validation',

            # Associates the current social details with another user account with
            # a similar email address. Disabled by default.
            # 'social_core.pipeline.social_auth.associate_by_email',

            # Create a user account if we haven't found one yet.
            'social_core.pipeline.user.create_user',

            # Create the record that associates the social account with the user.
            'social_core.pipeline.social_auth.associate_user',

            # Populate the extra_data field in the social record with the values
            # specified by settings (and the default ones like access_token, etc).
            'social_core.pipeline.social_auth.load_extra_data',

            # Update the user record with any changed info from the auth service.
            'social_core.pipeline.user.user_details',

            ###################
            # Custom pipelines
            ###################
            # Set authentik Groups
            'netbox.secshell_pipeline.add_groups',
            'netbox.secshell_pipeline.remove_groups',
            # Set Roles
            'netbox.secshell_pipeline.set_roles'
          )
        '';
      };
    })
  ]);
}
