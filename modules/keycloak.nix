{ config
, lib
, pkgs
, ...
}: {
  options.secshell.keycloak = {
    enable = lib.mkEnableOption "keycloak";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "auth.${toString config.networking.fqdn}";
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
        default = "";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "keycloak";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "keycloak";
      };
    };
    admin = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = null;
      };
      allowFrom = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];  # means from everywhere
      };
    };
  };
  config = lib.mkIf config.secshell.keycloak.enable {
    services.postgresql = lib.mkIf config.secshell.keycloak.useLocalDatabase {
      enable = true;
      ensureDatabases = ["keycloak"];
      userPasswords.keycloak = config.sops.secrets."keycloak/databasePassword".path;
    };

    services.keycloak = {
      enable = true;
      #plugins = [
      #  keycloak-restrict-client-auth
      #];
      database = {
        passwordFile = config.sops.secrets."keycloak/databasePassword".path;
        createLocally = false;
      } // (lib.optionalAttrs (! config.secshell.keycloak.useLocalDatabase) {
        useSSL = false;
        host = config.secshell.keycloak.database.hostname;
        username = config.secshell.keycloak.database.username;
        name = config.secshell.keycloak.database.name;
      });
      settings = {
        http-host = "127.0.0.1";
        http-port = config.secshell.keycloak.internal_port;
        proxy = "edge"; # Enables communication through HTTP between the proxy and Keycloak.

        hostname = config.secshell.keycloak.domain;
        hostname-strict = lib.mkIf (config.secshell.keycloak.admin.domain != null) false;
        #hostname-admin = lib.mkIf (config.secshell.keycloak.admin.domain != null) config.secshell.keycloak.admin.domain;

        metrics-enabled = true;
      };
      initialAdminPassword = "InitialKeycloakPassword";
    };

    services.nginx = let
      # transform given ip addresses (list of strings) to 'allow ELEMENT;' format for nginx
      allowedHosts = map (ip: "allow ${ip};") config.secshell.keycloak.admin.allowFrom;
    in {
      enable = true;
      virtualHosts = {
        "${toString config.secshell.keycloak.domain}" = {
          locations = {
            "= /".return = "307 https://${toString config.secshell.keycloak.domain}/realms/main/account/";
            "/" = {
              proxyPass = "http://127.0.0.1:${toString config.secshell.keycloak.internal_port}/";
              proxyWebsockets = true;
            };
            # depending on weather the admin domain is specified or not we configure this location
            "~* (/admin|/realms/master)" = if (config.secshell.keycloak.admin.domain == null) then {
              proxyPass = "http://127.0.0.1:${toString config.secshell.keycloak.internal_port}";
              proxyWebsockets = true;

              extraConfig = lib.mkIf ((lib.length config.secshell.keycloak.admin.allowFrom) != 0) ''
                ${lib.concatStringsSep "\n" allowedHosts}
                deny all;
              '';
            } else {
              return = "403";
            };
          };
          serverName = toString config.secshell.keycloak.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString config.secshell.keycloak.domain;
          forceSSL = true;
          
          extraConfig = ''
            proxy_busy_buffers_size 512k;
            proxy_buffers 4 512k;
            proxy_buffer_size 256k;
          '';
        };
        "${toString config.secshell.keycloak.admin.domain}" = lib.mkIf (config.secshell.keycloak.admin.domain != null) {
          locations = {
            "= /".return = "307 https://${toString config.secshell.keycloak.admin.domain}/admin/master/console/";
            "/" = {
              proxyPass = "http://127.0.0.1:${toString config.secshell.keycloak.internal_port}/";
              proxyWebsockets = true;
            };
            "~* (/admin|/realms/master)" = {
              proxyPass = "http://127.0.0.1:${toString config.secshell.keycloak.internal_port}";
              proxyWebsockets = true;
              
              extraConfig = lib.mkIf ((lib.length config.secshell.keycloak.admin.allowFrom) != 0) ''
                ${lib.concatStringsSep "\n" allowedHosts}
                deny all;
              '';
            };
          };
          serverName = toString config.secshell.keycloak.admin.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString config.secshell.keycloak.admin.domain;
          forceSSL = true;
        };
      };
    };
    security.acme.certs."${toString config.secshell.keycloak.domain}" = {};
    security.acme.certs."${toString config.secshell.keycloak.admin.domain}" = lib.mkIf (config.secshell.keycloak.admin.domain != null) {};
  };
}
