{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.secshell.unifi;
in
{
  options.secshell.unifi = {
    enable = lib.mkEnableOption "unifi";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "unifi.${toString config.networking.fqdn}";
      defaultText = "unifi.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for this service.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    services.unifi = {
      enable = true;
      unifiPackage = pkgs.unifi;
      mongodbPackage = pkgs.mongodb-ce;
    };

    networking.firewall = {
      allowedTCPPorts = [
        8080
        8443
        8843
        6789
        8880
      ];
      allowedUDPPorts = [
        546
        5514
        3478
        10001
      ];
    };

    systemd.tmpfiles.rules = [ "d /var/lib/unifi 0755 root root" ];

    services.nginx = {
      enable = true;
      virtualHosts."${toString cfg.domain}" = {
        locations."/" = {
          proxyPass = "https://127.0.0.1:8443";
          proxyWebsockets = true;
        };
        serverName = toString cfg.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString cfg.domain;
        forceSSL = true;
      };
    };
    security.acme.certs."${toString cfg.domain}" = { };
  };
}
