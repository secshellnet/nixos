{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  # Note for initial installation / database initialization: systemd timeout is way to small to finish the whole setup.
  # Run the deployment (or netbox systemd job) multiple times, until it works (arround 5 times required)

  options.secshell.netbox = {
    enable = lib.mkEnableOption "netbox";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "netbox.${toString config.networking.fqdn}";
      defaultText = "netbox.\${toString config.networking.fqdn}";
    };
    internal_port = lib.mkOption { type = lib.types.port; };
    oidc = {
      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      clientId = lib.mkOption {
        type = lib.types.str;
        default = config.secshell.netbox.domain;
        defaultText = "config.secshell.netbox.domain";
      };
    };
    useLocalDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    database = {
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "netbox";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "netbox";
      };
    };
    plugin = {
      bgp = lib.mkEnableOption "netbox bgp plugin";
      documents = lib.mkEnableOption "netbox documents plugin";
      floorplan = lib.mkEnableOption "netbox floorplan plugin";
      qrcode = lib.mkEnableOption "netbox qrcode plugin";
      topologyViews = lib.mkEnableOption "netbox topology views plugin";
      proxbox = lib.mkEnableOption "netbox proxbox plugin";
      contract = lib.mkEnableOption "netbox contract plugin";
      interface-synchronization = lib.mkEnableOption "netbox interface-synchronization plugin";
      dns = lib.mkEnableOption "netbox dns plugin";
      napalm = lib.mkEnableOption "netbox napalm plugin";
      reorder-rack = lib.mkEnableOption "netbox reorder-rack plugin";
      prometheus-sd = lib.mkEnableOption "netbox prometheus-sd plugin";
      kea = lib.mkEnableOption "netbox kea plugin";
      attachments = lib.mkEnableOption "netbox attachments plugin";
      branching = lib.mkEnableOption "netbox branching plugin";
    };
  };
  config = lib.mkIf config.secshell.netbox.enable {
    sops.secrets =
      {
        "netbox/secretKey".owner = "netbox";
      }
      // (lib.optionalAttrs (config.secshell.netbox.oidc.endpoint != "") {
        "netbox/socialAuthSecret".owner = "netbox";
      })
      // (lib.optionalAttrs (!config.secshell.netbox.useLocalDatabase) {
        "netbox/databasePassword".owner = "netbox";
      });

    services = {
      postgresql = {
        enable = lib.mkForce config.secshell.netbox.useLocalDatabase;
        ensureDatabases = lib.mkIf config.secshell.netbox.useLocalDatabase [ "netbox" ];
      };

      netbox = {
        enable = true;
        package =
          if config.secshell.netbox.oidc.endpoint != "" then
            pkgs-unstable.netbox.overrideAttrs (old: {
              installPhase =
                old.installPhase
                + ''
                  ln -s ${./pipeline.py} $out/opt/netbox/netbox/netbox/secshell_pipeline.py
                '';
            })
          else
            pkgs-unstable.netbox;
        secretKeyFile = config.sops.secrets."netbox/secretKey".path;
        port = config.secshell.netbox.internal_port;
        listenAddress = "127.0.0.1";
        settings =
          {
            LOGIN_REQUIRED = true;
            TIME_ZONE = "Europe/Berlin";
            METRICS_ENABLED = true;
          }
          // (lib.optionalAttrs (config.secshell.netbox.oidc.endpoint != "") {
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
            SOCIAL_AUTH_OIDC_OIDC_ENDPOINT = config.secshell.netbox.oidc.endpoint;
            SOCIAL_AUTH_OIDC_KEY = config.secshell.netbox.oidc.clientId;
            LOGOUT_REDIRECT_URL = "${config.secshell.netbox.oidc.endpoint}end-session/";
          })
          // {
            PLUGINS = [
              (lib.mkIf config.secshell.netbox.plugin.bgp "netbox_bgp")
              (lib.mkIf config.secshell.netbox.plugin.documents "netbox_documents")
              (lib.mkIf config.secshell.netbox.plugin.floorplan "netbox_floorplan")
              (lib.mkIf config.secshell.netbox.plugin.qrcode "netbox_qrcode")
              (lib.mkIf config.secshell.netbox.plugin.topologyViews "netbox_topology_views")
              #(lib.mkIf config.secshell.netbox.plugin.proxbox "netbox_proxbox")
              (lib.mkIf config.secshell.netbox.plugin.contract "netbox_contract")
              (lib.mkIf config.secshell.netbox.plugin.interface-synchronization "netbox_interface_synchronization")
              (lib.mkIf config.secshell.netbox.plugin.dns "netbox_dns")
              (lib.mkIf config.secshell.netbox.plugin.napalm "netbox_napalm_plugin")
              (lib.mkIf config.secshell.netbox.plugin.reorder-rack "netbox_reorder_rack")
              (lib.mkIf config.secshell.netbox.plugin.prometheus-sd "netbox_prometheus_sd")
              (lib.mkIf config.secshell.netbox.plugin.kea "netbox_kea")
              (lib.mkIf config.secshell.netbox.plugin.attachments "netbox_attachments")
              # netbox-branching README: Note that netbox_branching MUST be the last plugin listed.
              (lib.mkIf config.secshell.netbox.plugin.branching "netbox_branching")
            ];
          };

        plugins =
          ps:
          let
            plugins = ps.callPackage ./plugins { };
          in
          [
            (lib.mkIf config.secshell.netbox.plugin.bgp (
              ps.netbox-bgp.overridePythonAttrs (previous: {
                version = "0.15.0";
                src = previous.src.override {
                  tag = "0.15.0";
                  hash = "sha256-2PJD/6WjFQRfreK2kpWIYXb5r4noJBa8zejK5r+A+xA=";
                };
              })
            ))

            (lib.mkIf config.secshell.netbox.plugin.documents (
              ps.netbox-documents.overridePythonAttrs (previous: {
                version = "0.7.2";
                src = previous.src.override {
                  tag = "v0.7.2";
                  hash = "sha256-AJuWzZSVsodShLIfdlhLN8ycnC28DULcINCD3av35jI=";
                };
                dependencies = [
                  (ps.drf-extra-fields.overridePythonAttrs (previous: {
                    nativeCheckInputs = previous.nativeCheckInputs ++ [ ps.pytz ];
                    disabledTests = [
                      "test_create"
                      "test_create_with_base64_prefix"
                      "test_create_with_webp_image"
                      "test_remove_with_empty_string"
                    ];
                  }))
                ];
              })
            ))
            (lib.mkIf config.secshell.netbox.plugin.floorplan ps.netbox-floorplan-plugin)
            (lib.mkIf config.secshell.netbox.plugin.qrcode ps.netbox-qrcode)
            (lib.mkIf config.secshell.netbox.plugin.topologyViews (
              ps.netbox-topology-views.overridePythonAttrs (previous: {
                version = "4.2.1";
                src = previous.src.override {
                  tag = "v4.2.1";
                  hash = "sha256-ysupqyRFOKVa+evNbfSdW2W57apI0jVEU92afz6+AaE=";
                };
              })
            ))
            #(lib.mkIf config.secshell.netbox.plugin.proxbox plugins.netbox-proxbox)
            (lib.mkIf config.secshell.netbox.plugin.contract plugins.netbox-contract)
            (lib.mkIf config.secshell.netbox.plugin.interface-synchronization ps.netbox-interface-synchronization)
            (lib.mkIf config.secshell.netbox.plugin.dns (
              ps.netbox-dns.overridePythonAttrs (previous: {
                version = "1.2.11";
                src = previous.src.override {
                  tag = "1.2.11";
                  hash = "sha256-cT2nvPDsvZBVuhvvORtxwb2TDHqnSpvpIJFkGZy1CEc=";
                };
              })
            ))
            (lib.mkIf config.secshell.netbox.plugin.napalm (
              ps.netbox-napalm-plugin.overridePythonAttrs (previous: {
                dependencies = previous.dependencies ++ [ ps.napalm-ros ];
              })
            ))
            (lib.mkIf config.secshell.netbox.plugin.reorder-rack ps.netbox-reorder-rack)
            (lib.mkIf config.secshell.netbox.plugin.prometheus-sd ps.netbox-plugin-prometheus-sd)
            (lib.mkIf config.secshell.netbox.plugin.kea plugins.netbox-kea)
            (lib.mkIf config.secshell.netbox.plugin.attachments plugins.netbox-attachments)
            (lib.mkIf config.secshell.netbox.plugin.branching plugins.netbox-branching)
          ];

        # see https://docs.netbox.dev/en/stable/configuration/required-parameters/#database
        extraConfig = ''
          ${lib.optionalString (!config.secshell.netbox.useLocalDatabase) ''
            DATABASE = {
              'ENGINE': 'django.db.backends.postgresql',
              'NAME': '${config.secshell.netbox.database.name}',
              'USER': '${config.secshell.netbox.database.username}',
              'HOST': '${config.secshell.netbox.database.hostname}',
              'CONN_MAX_AGE': 300,
            }
            with open("${config.sops.secrets."netbox/databasePassword".path}", "r") as file:
              DATABASE['PASSWORD'] = file.readline()
          ''}

          ${lib.optionalString config.secshell.netbox.plugin.branching ''
            from netbox_branching.utilities import DynamicSchemaDict

            DATABASES = DynamicSchemaDict(DATABASE)

            # unset DATABASE variable
            if 'DATABASE' in globals():
                del DATABASE

            DATABASE_ROUTERS = [
                'netbox_branching.database.BranchAwareRouter',
            ]
          ''}

          ${lib.optionalString (config.secshell.netbox.oidc.endpoint != "") ''
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
          ''}
        '';
      };
      nginx = {
        enable = true;
        virtualHosts."${toString config.secshell.netbox.domain}" = {
          locations = {
            "/".proxyPass = "http://127.0.0.1:${toString config.secshell.netbox.internal_port}";
            "/static/".alias = "${config.services.netbox.dataDir}/static/";
          };
          serverName = toString config.secshell.netbox.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString config.secshell.netbox.domain;
          forceSSL = true;
        };
      };
    };
    security.acme.certs."${toString config.secshell.netbox.domain}" = { };

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
  };
}
