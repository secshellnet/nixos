{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  cfg = config.secshell.gitea.woodpecker;
in
{
  config = lib.mkIf (config.secshell.gitea.enable && cfg.enable && cfg.enableServer) {
    sops = {
      secrets = {
        "woodpecker/secret" = { };
        "woodpecker/oidcClientId" = { };
        "woodpecker/oidcSecret" = { };
      };
      templates."woodpecker/environment".content = ''
        WOODPECKER_AGENT_SECRET=${config.sops.placeholder."woodpecker/secret"}
        WOODPECKER_GITEA_CLIENT=${config.sops.placeholder."woodpecker/oidcClientId"}
        WOODPECKER_GITEA_SECRET=${config.sops.placeholder."woodpecker/oidcSecret"}
      '';
    };

    services = {
      woodpecker-server = {
        enable = true;
        package = pkgs-unstable.woodpecker-server;
        environment = {
          WOODPECKER_HOST = "https://${cfg.domain}";
          WOODPECKER_SERVER_ADDR = "127.0.0.1:${toString cfg.internal_port}";
          WOODPECKER_GRPC_ADDR = "${cfg.grpc_addr}:${toString cfg.grpc_port}";
          WOODPECKER_OPEN = "true";

          WOODPECKER_GITEA = "true";
          WOODPECKER_GITEA_URL = config.services.gitea.settings.server.ROOT_URL;
          WOODPECKER_AUTHENTICATE_PUBLIC_REPOS = "true";
        };
        environmentFile = config.sops.templates."woodpecker/environment".path;
      };

      nginx = lib.mkIf cfg.enableServer {
        enable = true;
        virtualHosts."${toString cfg.domain}" = {
          locations = {
            "/".proxyPass = "http://127.0.0.1:${toString cfg.internal_port}";
          };
          serverName = toString cfg.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString cfg.domain;
          forceSSL = true;
        };
      };
    };
    security.acme.certs."${toString cfg.domain}" = { };
  };
}
