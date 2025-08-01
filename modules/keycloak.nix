{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.secshell.keycloak = {
    enable = lib.mkEnableOption "keycloak";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "auth.${toString config.networking.fqdn}";
      defaultText = "auth.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for this service.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
    internal_port = lib.mkOption {
      type = lib.types.port;
      description = ''
        The local port the service listens on.
      '';
    };
    useLocalDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to use a local database instance for this service.
        When enabled (default), the service will deploy and manage
        its own postgres database. When disabled, you must configure external
        database connection parameters separately.
      '';
    };
    database = {
      hostname = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Database server hostname. Not required if local database is being used.
        '';
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "keycloak";
        description = ''
          Database user account with read/write privileges.
          For PostgreSQL, ensure the user has CREATEDB permission
          for initial setup if creating databases automatically.
        '';
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "keycloak";
        description = ''
          Name of the database to use.
          Will be created automatically if the user has permissions.
        '';
      };
    };
    admin = {
      #domain = lib.mkOption {
      #  type = lib.types.str;
      #  default = "";
      #};
      allowFrom = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Source ip networks from which access to the admin interface is allowed.
          Defaults to an empty array, which means from everywhere.
        '';
      };
    };
  };
  config = lib.mkIf config.secshell.keycloak.enable {
    sops.secrets."keycloak/databasePassword" = {
      owner = lib.mkIf config.secshell.keycloak.useLocalDatabase "postgres";
    };

    services.postgresql = lib.mkIf config.secshell.keycloak.useLocalDatabase {
      enable = true;
      ensureDatabases = [ "keycloak" ];
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
      }
      // (lib.optionalAttrs (!config.secshell.keycloak.useLocalDatabase) {
        useSSL = false;
        host = config.secshell.keycloak.database.hostname;
        username = config.secshell.keycloak.database.username;
        name = config.secshell.keycloak.database.name;
      });
      settings = {
        http-host = "127.0.0.1";
        https-port = config.secshell.keycloak.internal_port;
        proxy-headers = "forwarded"; # Enables communication through HTTP between the proxy and Keycloak.

        hostname = config.secshell.keycloak.domain;
        #hostname-strict = lib.mkIf (config.secshell.keycloak.admin.domain != "") false;
        #hostname-admin = lib.mkIf (config.secshell.keycloak.admin.domain != "") config.secshell.keycloak.admin.domain;

        metrics-enabled = true;
      };
      sslCertificateKey = "/var/lib/acme/${toString config.secshell.keycloak.domain}/key.pem";
      sslCertificate = "/var/lib/acme/${toString config.secshell.keycloak.domain}/fullchain.pem";
      initialAdminPassword = "InitialKeycloakPassword";
    };

    systemd.services.keycloak.preStart = lib.mkIf (!config.secshell.keycloak.useLocalDatabase) ''
      echo 'Checking if configured external database is reachable!'
      while ! ${pkgs.netcat}/bin/nc -z "${config.secshell.keycloak.database.hostname}" "5432"; do
        sleep 0.1
      done
      echo 'PostgreSQL database is reachable! Starting keycloak...'
    '';

    services.nginx =
      let
        # transform given ip addresses (list of strings) to 'allow ELEMENT;' format for nginx
        allowedHosts = map (ip: "allow ${ip};") config.secshell.keycloak.admin.allowFrom;
      in
      {
        enable = true;
        virtualHosts = {
          "${toString config.secshell.keycloak.domain}" = {
            locations = {
              "= /".return = "307 https://${toString config.secshell.keycloak.domain}/realms/main/account/";
              "/" = {
                proxyPass = "https://127.0.0.1:${toString config.secshell.keycloak.internal_port}/";
                proxyWebsockets = true;
              };
              # depending on weather the admin domain is specified or not we configure this location
              "~* (/admin|/realms/master)" = # if (config.secshell.keycloak.admin.domain == "") then
                {
                  proxyPass = "https://127.0.0.1:${toString config.secshell.keycloak.internal_port}";
                  proxyWebsockets = true;

                  extraConfig = lib.mkIf ((lib.length config.secshell.keycloak.admin.allowFrom) != 0) ''
                    ${lib.concatStringsSep "\n" allowedHosts}
                    deny all;
                  '';
                  /*
                    } else {
                    return = "403";
                  */
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
          #"${toString config.secshell.keycloak.admin.domain}" = lib.mkIf (config.secshell.keycloak.admin.domain != "") {
          #  locations = {
          #    "= /".return = "307 https://${toString config.secshell.keycloak.admin.domain}/admin/master/console/";
          #    "/" = {
          #      proxyPass = "https://127.0.0.1:${toString config.secshell.keycloak.internal_port}/";
          #      proxyWebsockets = true;
          #    };
          #    "~* (/admin|/realms/master)" = {
          #      proxyPass = "https://127.0.0.1:${toString config.secshell.keycloak.internal_port}";
          #      proxyWebsockets = true;
          #
          #      extraConfig = lib.mkIf ((lib.length config.secshell.keycloak.admin.allowFrom) != 0) ''
          #        ${lib.concatStringsSep "\n" allowedHosts}
          #        deny all;
          #      '';
          #    };
          #  };
          #  serverName = toString config.secshell.keycloak.admin.domain;

          #  # use ACME DNS-01 challenge
          #  useACMEHost = toString config.secshell.keycloak.admin.domain;
          #  forceSSL = true;
          #};
        };
      };
    security.acme.certs."${toString config.secshell.keycloak.domain}" = { };
    #security.acme.certs."${toString config.secshell.keycloak.admin.domain}" = lib.mkIf (config.secshell.keycloak.admin.domain != "") {};
  };
}
