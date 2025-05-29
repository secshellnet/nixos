{
  config,
  lib,
  ...
}:
{
  options.secshell.matrix = {
    enable = lib.mkEnableOption "matrix-synapse";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "synapse.${toString config.networking.fqdn}";
      defaultText = "synapse.\${toString config.networking.fqdn}";
      description = ''
        The domain for the nginx vhost, which makes synapse accessible.
        Note: A tls certificate will be issued using acme for this domain.
      '';
    };
    internal_port = lib.mkOption {
      type = lib.types.port;
      description = ''
        The port that is used internally to forward traffic from nginx to synapse.
      '';
    };
    metrics_port = lib.mkOption {
      type = lib.types.port;
      default = 9089;
      description = ''
        The port that is used internally to access prometheus metrics from synapse.
      '';
    };
    homeserver = lib.mkOption {
      type = lib.types.str;
      description = ''
        The domain of the matrix synapse homeserver.
        Note: This domain will be used in your matrix id: @user:domain.
      '';
    };
    oidc = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  config = lib.mkIf config.secshell.matrix.enable {
    sops.secrets."matrix/synapse/secrets" = lib.mkIf config.secshell.matrix.oidc {
      owner = "matrix-synapse";
    };
    # Example value for secret, see https://matrix-org.github.io/synapse/latest/openid.html#keycloak
    #matrix:
    #  synapse:
    #    secrets: |
    #      oidc_providers:
    #        - idp_id: keycloak
    #          idp_name: Keycloak
    #          issuer: "https://auth.example.com/realms/main"
    #          client_id: ""
    #          client_secret: ""
    #          scopes: ["openid", "profile"]

    services.postgresql = {
      enable = true;
      ensureUsers = [ { name = "matrix-synapse"; } ];
    };
    systemd.services.postgresql.postStart =
      let
        inherit (config.services.matrix-synapse.settings.database.args) database;
      in
      lib.mkAfter ''
        $PSQL -tAc "SELECT 1 FROM pg_database WHERE datname = 'matrix-synapse'" | grep -q 1 || $PSQL -tAc 'CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse" TEMPLATE template0 LC_COLLATE = "C" LC_CTYPE = "C"'
      '';

    services.matrix-synapse = {
      enable = true;
      extraConfigFiles = lib.mkIf config.secshell.matrix.oidc [
        config.sops.secrets."matrix/synapse/secrets".path
      ];
      extras = lib.mkIf config.secshell.matrix.oidc [ "oidc" ];
      settings = {
        server_name = config.secshell.matrix.homeserver;
        public_baseurl = "https://${config.secshell.matrix.domain}/";
        web_client_location = "https://app.element.io/";
        allow_public_rooms_over_federation = true;
        enable_registration = lib.mkDefault false;
        password_config.enabled = !config.secshell.matrix.oidc; # allow login using username/password (disable for oidc)
        max_upload_size = "500M";

        listeners =
          [
            {
              bind_addresses = [ "127.0.0.1" ];
              port = config.secshell.matrix.internal_port;
              type = "http";
              tls = false;
              x_forwarded = true;
              resources = [
                {
                  names = [
                    "client"
                    "federation"
                  ];
                  compress = false;
                }
              ];
            }
          ]
          ++ (lib.optionalAttrs (!config.services.matrix-synapse.settings.enable_metrics) [
            {
              bind_addresses = [ "127.0.0.1" ];
              port = config.secshell.matrix.metrics_port;
              type = "http";
              tls = false;
              x_forwarded = true;
              resources = [
                {
                  names = [ "metrics" ];
                  compress = false;
                }
              ];
            }
          ]);
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${toString config.secshell.matrix.domain} = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.secshell.matrix.internal_port}";
          proxyWebsockets = true;
          extraConfig = ''
            client_max_body_size 500M;
          '';
        };
        serverName = toString config.secshell.matrix.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.secshell.matrix.domain;
        forceSSL = true;
      };
    };

    security.acme.certs."${toString config.secshell.matrix.domain}" = { };
  };
}
