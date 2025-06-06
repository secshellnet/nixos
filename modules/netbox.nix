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
        default = config.secshell.netbox.domain;
        defaultText = "config.secshell.netbox.domain";
      };
      pubkey = lib.mkOption {
        type = lib.types.str;
        default = "";
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
    };
  };
  config = lib.mkIf config.secshell.netbox.enable {
    sops.secrets =
      {
        "netbox/secretKey".owner = "netbox";
      }
      // (lib.optionalAttrs (config.secshell.netbox.oidc.domain != "") {
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
        package = pkgs-unstable.netbox;
        secretKeyFile = config.sops.secrets."netbox/secretKey".path;
        port = config.secshell.netbox.internal_port;
        listenAddress = "127.0.0.1";
        settings =
          {
            LOGIN_REQUIRED = true;
            TIME_ZONE = "Europe/Berlin";
            METRICS_ENABLED = true;
          }
          // (lib.optionalAttrs (config.secshell.netbox.oidc.domain != "") {
            # https://stackoverflow.com/questions/53550321/keycloak-gatekeeper-aud-claim-and-client-id-do-not-match
            REMOTE_AUTH_ENABLED = true;
            REMOTE_AUTH_AUTO_CREATE_USER = true;
            REMOTE_AUTH_GROUP_SYNC_ENABLED = true;
            REMOTE_AUTH_BACKEND = "social_core.backends.keycloak.KeycloakOAuth2";

            #REMOTE_AUTH_GROUP_SEPARATOR=",";
            REMOTE_AUTH_SUPERUSER_GROUPS = [ "superuser" ];
            REMOTE_AUTH_STAFF_GROUPS = [ "staff" ];
            REMOTE_AUTH_DEFAULT_GROUPS = [ "staff" ];

            SOCIAL_AUTH_KEYCLOAK_KEY = config.secshell.netbox.oidc.clientId;
            SOCIAL_AUTH_KEYCLOAK_PUBLIC_KEY = config.secshell.netbox.oidc.pubkey;
            SOCIAL_AUTH_KEYCLOAK_AUTHORIZATION_URL = "https://${config.secshell.netbox.oidc.domain}/realms/${config.secshell.netbox.oidc.realm}/protocol/openid-connect/auth";
            SOCIAL_AUTH_KEYCLOAK_ACCESS_TOKEN_URL = "https://${config.secshell.netbox.oidc.domain}/realms/${config.secshell.netbox.oidc.realm}/protocol/openid-connect/token";
            SOCIAL_AUTH_KEYCLOAK_ID_KEY = "email";
            SOCIAL_AUTH_JSONFIELD_ENABLED = true;
            SOCIAL_AUTH_VERIFY_SSL = true;
            #SOCIAL_AUTH_OIDC_SCOPE = ["groups" "roles"];
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
            ];
          };

        plugins =
          ps:
          let
            plugins = ps.callPackage ./netbox-plugins { };
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
          ];

        # see https://docs.netbox.dev/en/stable/configuration/required-parameters/#database
        extraConfig = lib.mkIf (!config.secshell.netbox.useLocalDatabase) ''
          DATABASE = {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': '${config.secshell.netbox.database.name}',
            'USER': '${config.secshell.netbox.database.username}',
            'HOST': '${config.secshell.netbox.database.hostname}',
            'CONN_MAX_AGE': 300,
          }
          with open("${config.sops.secrets."netbox/databasePassword".path}", "r") as file:
            DATABASE['PASSWORD'] = file.readline()
        '';

        keycloakClientSecret = lib.mkIf (
          config.secshell.netbox.oidc.domain != ""
        ) config.sops.secrets."netbox/socialAuthSecret".path;
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
