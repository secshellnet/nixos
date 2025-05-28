{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  options.secshell.unifi = {
    enable = lib.mkEnableOption "unifi";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "unifi.${toString config.networking.fqdn}";
      defaultText = "unifi.\${toString config.networking.fqdn}";
    };
  };
  config = lib.mkIf config.secshell.unifi.enable {
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
      virtualHosts."${toString config.secshell.unifi.domain}" = {
        locations."/" = {
          proxyPass = "https://127.0.0.1:8443";
          proxyWebsockets = true;
        };
        serverName = toString config.secshell.unifi.domain;

        # use ACME DNS-01 challenge
        useACMEHost = toString config.secshell.unifi.domain;
        forceSSL = true;
      };
    };
    security.acme.certs."${toString config.secshell.unifi.domain}" = { };
  };
}
